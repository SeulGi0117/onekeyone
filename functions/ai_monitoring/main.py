import sys
import torch
from torchvision import transforms
from PIL import Image
import base64
import io
import os
import matplotlib.pyplot as plt
import firebase_admin
from firebase_admin import credentials, db
from datetime import datetime
import schedule
import time
import platform

def log_with_timestamp(message):
    current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{current_time}] {message}")

class PlantHealthMonitor:
    def __init__(self):
        log_with_timestamp("PlantHealthMonitor 초기화 시작")
        # Firebase 초기화
        cred = credentials.Certificate("D:/my_plant/functions/src/model/aaaa-8a6a5-firebase-adminsdk-1wmfe-d3f93bba70.json")
        firebase_admin.initialize_app(cred, {
            'databaseURL': 'https://aaaa-8a6a5-default-rtdb.firebaseio.com'
        })

        # 상수 정의
        self.DEVICE = torch.device("cpu")
        self.YOLO_MODEL_PATH = os.path.abspath("D:/my_plant/functions/src/model/last_yolo.pt")
        self.EFFICIENT_MODEL_PATH = os.path.abspath("D:/my_plant/functions/src/model/efficient_best_loss_model_0.0157.pt")
        
        # Windows에서 PosixPath 오류 해결을 위한 패치
        if platform.system() == 'Windows':
            import pathlib
            temp = pathlib.PosixPath
            pathlib.PosixPath = pathlib.WindowsPath
        
        # YOLO 모델 로드 (캐시 사용)
        try:
            print("YOLO 모델 로딩 시작...")
            # 캐시된 모델 확인
            cache_dir = os.path.join(os.path.expanduser("~"), ".cache", "torch", "hub", "yolov5")
            if not os.path.exists(cache_dir):
                os.makedirs(cache_dir)
            
            self.yolo_model = torch.hub.load('ultralytics/yolov5', 'custom', 
                                           path=self.YOLO_MODEL_PATH, 
                                           device=self.DEVICE,
                                           force_reload=False)  # force_reload를 False로 변경
            print("YOLO 모델 로딩 완료")
        except Exception as e:
            print(f"YOLO 모델 로딩 실패: {e}")
            raise
        
        try:
            print("EfficientNet 모델 로딩 시작...")
            self.efficient_model = self.load_efficient_model()
            print("EfficientNet 모델 로딩 완료")
        except Exception as e:
            print(f"EfficientNet 모델 로딩 실패: {e}")
            raise
        
        # EfficientNet 관련 설정
        self.c_mean = [0.45596054, 0.4746459, 0.39278948]
        self.c_std = [0.04770943, 0.05074333, 0.0420883]
        self.transform = transforms.Compose([
            transforms.Resize((224, 224)),
            transforms.ToTensor(),
            transforms.Normalize(self.c_mean, self.c_std)
        ])
        
        self.CLASSES = ['Apple___Apple_scab', 'Apple___Black_rot', 'Apple___Cedar_apple_rust',
     'bottle_gourd___Leaf Spot', 'Cherry___Powdery_mildew',
     'eggplant___Epilachna Beetle', 'eggplant___Jassid', 'Grape___Black_rot',
     'Grape___Esca_(Black_Measles)',
     'Grape___Leaf_blight_(Isariopsis_Leaf_Spot)', 'Peach___Bacterial_spot',
     'Pepper,_bell___Bacterial_spot', 'plant___healthy', 'plant___overwartering',
     'plant___Powdery Mildew', 'plant___Underwatering', 'Potato___Early_blight',
     'Potato___Late_blight', 'ridge_gourd___Pumpkin Caterpillar',
     'ridge_gourd___Pumpkin Leaf Eating Insect',
     'ridge_gourd___Pumpkin Leaf Eating Insect and Insect Egg Mass',
     'ridge_gourd___Pumpkin Leaf Eating Insect and Mite',
     'Squash___Powdery_mildew', 'Strawberry___Leaf_scorch',
     'Tomato___Bacterial_spot']

    def load_efficient_model(self):
        model = torch.load(self.EFFICIENT_MODEL_PATH, map_location=self.DEVICE)
        model.eval()
        return model

    def get_image_from_firebase(self, node_path):
        """Firebase에서 이미지 가져오기"""
        try:
            ref = db.reference(f'{node_path}/ESP32CAM')
            encoded_image = ref.get()
            
            if encoded_image.startswith("data:image"):
                encoded_image = encoded_image.split(",")[1]
            
            image_data = base64.b64decode(encoded_image)
            image = Image.open(io.BytesIO(image_data)).convert("RGB")
            print(f"실시간 이미지 가져오기 완료")
            return image
        except Exception as e:
            print(f"실시간 이미지 가져오기 실패: {e}")
            return None

    def analyze_with_yolo(self, image):
        """YOLO 분석 수행"""
        try:
            # 임시 파일로 저장
            temp_path = "temp_image.jpg"
            image.save(temp_path)
            
            results = self.yolo_model(temp_path)
            df_results = results.pandas().xyxy[0]
            
            os.remove(temp_path)  # 임시 파일 삭제
            print("YOLO 분석 완료")
            return df_results
        except Exception as e:
            print(f"YOLO 분석 실패: {e}")
            return None

    def analyze_disease(self, cropped_image_path):
        """EfficientNet으로 질병 분석"""
        try:
            image = Image.open(cropped_image_path).convert('RGB')
            image_tensor = self.transform(image).unsqueeze(0)
            
            with torch.no_grad():
                outputs = self.efficient_model(image_tensor)
                _, predicted = torch.max(outputs, 1)
                disease_name = self.CLASSES[predicted.item()]
                print(f"질병 분석 완료: {disease_name}")
            
            return disease_name
            
        except Exception as e:
            print(f"질병 분석 실패: {e}")
            return None

    def update_plant_status(self, plant_id, status, disease=None):
        """Firebase에 상태 업데이트"""
        try:
            ref = db.reference(f'plants/{plant_id}/health_status')
            ref.set({
                'status': status,
                'disease': disease if disease else "없음",
                'timestamp': datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            })
            print(f"상태 업데이트 완료: {plant_id}")
        except Exception as e:
            print(f"상태 업데이트 실패: {e}")

    def process_plant(self, sensor_node, plant_id):
        """단일 식물 처리"""
        try:
            print(f"\n{'='*50}")
            print(f"식물 ID: {plant_id} 분석 프로세스 시작")
            print(f"센서 노드: {sensor_node}")
            
            # 이미지 가져오기
            print("\n1. 실시간 이미지 가져오기 시작...")
            image = self.get_image_from_firebase(sensor_node)
            if image is None:
                print("❌ 이미지를 가져올 수 없음 - status를 'Unknown'으로 업데이트")
                plant_ref = db.reference(f'plants/{plant_id}')
                plant_ref.update({
                    'status': 'Unknown',
                    'lastUpdated': datetime.now().isoformat()
                })
                return
            print("✅ 실시간 이미지 가져오기 성공")
            
            # YOLO 분석
            print("\n2. YOLO 모델 분석 시작...")
            results = self.analyze_with_yolo(image)
            if results is None:
                print("❌ YOLO 분석 실패 - status를 'Unknown'으로 업데이트")
                plant_ref = db.reference(f'plants/{plant_id}')
                plant_ref.update({
                    'status': 'Unknown',
                    'lastUpdated': datetime.now().isoformat()
                })
                return
            print("✅ YOLO 분석 완료")
            print(f"YOLO 분석 결과: {results}")
            
            # Unhealthy 잎 확인
            unhealthy_results = results[results['name'].str.lower() == 'unhealthy']
            plant_ref = db.reference(f'plants/{plant_id}')
            
            if not unhealthy_results.empty:
                print("\n3. 비정상 잎 감지됨 - EfficientNet 분석 시작...")
                first_unhealthy = unhealthy_results.iloc[0]
                bbox = [int(first_unhealthy[c]) for c in ['xmin', 'ymin', 'xmax', 'ymax']]
                print(f"감지된 영역: {bbox}")
                
                cropped = image.crop(bbox)
                crop_path = f"temp_crop_{plant_id}.jpg"
                cropped.save(crop_path)
                
                # 질병 분석
                disease = self.analyze_disease(crop_path)
                os.remove(crop_path)
                
                if disease:
                    print(f"✅ 질병 감지: {disease}")
                    print(f"상태 업데이트 중: '{disease}'")
                    plant_ref.update({
                        'status': disease,
                        'lastUpdated': datetime.now().isoformat()
                    })
                    print("상태 업데이트 완료")
                else:
                    print("❌ 질병 분석 실패 - status를 'Unknown'으로 업데이트")
                    plant_ref.update({
                        'status': 'Unknown',
                        'lastUpdated': datetime.now().isoformat()
                    })
            else:
                print("\n3. 정상 상태 감지")
                print("상태 업데이트 중: 'healthy'")
                plant_ref.update({
                    'status': 'healthy',
                    'lastUpdated': datetime.now().isoformat()
                })
                print("상태 업데이트 완료")
            
            print(f"\n{'='*50}")
            print(f"식물 ID: {plant_id} 분석 완료")
            print(f"{'='*50}\n")
                
        except Exception as e:
            print(f"\n❌ 오류 발생: {e}")
            try:
                plant_ref = db.reference(f'plants/{plant_id}')
                plant_ref.update({
                    'status': 'Unknown',
                    'lastUpdated': datetime.now().isoformat()
                })
                print(f"오류로 인해 status를 'Unknown'으로 업데이트")
            except Exception as update_error:
                print(f"상태 업데이트 실패: {update_error}")

    def check_all_plants(self):
        log_with_timestamp("모든 식물 체크 시작")
        try:
            nodes = ['JSON', 'JSON2', 'JSON3']
            plants_ref = db.reference('plants')
            plants = plants_ref.get()
            
            if plants:
                for plant_id, plant_data in plants.items():
                    node = plant_data.get('sensorNode')
                    if node in nodes:
                        self.process_plant(node, plant_id)
            log_with_timestamp("모든 식물 체크 완료")
                        
        except Exception as e:
            log_with_timestamp(f"전체 식물 체크 중 오류 발생: {e}")

def main():
    log_with_timestamp("프로그램 시작")
    
    # 커맨드 라인 인자 처리
    if len(sys.argv) > 2:
        plant_id = sys.argv[1]
        sensor_node = sys.argv[2]
        
        monitor = PlantHealthMonitor()
        monitor.process_plant(sensor_node, plant_id)
    else:
        log_with_timestamp("자동 모니터링 모드 시작")
        monitor = PlantHealthMonitor()
        
        def handle_trigger(event):
            if event.data:
                log_with_timestamp(f"\n{'='*50}")
                log_with_timestamp("분석 요청 감지! 분석을 시작합니다.")
                
                try:
                    # 트리거 데이터 확인
                    trigger_data = event.data
                    request_type = trigger_data.get('requestType')
                    
                    if request_type == 'manual':
                        # 단일 식물 분석
                        plant_id = trigger_data.get('plantId')
                        sensor_node = trigger_data.get('sensorNode')
                        
                        if plant_id and sensor_node:
                            log_with_timestamp(f"식물 분석 시작 - ID: {plant_id}, Node: {sensor_node}")
                            monitor.process_plant(sensor_node, plant_id)
                            log_with_timestamp("식물 분석 완료")
                    else:
                        # 모든 식물 분석
                        nodes = ['JSON', 'JSON2', 'JSON3']
                        plants_ref = db.reference('plants')
                        plants = plants_ref.get()
                        
                        if plants:
                            total_plants = len(plants)
                            current_count = 0
                            
                            for plant_id, plant_data in plants.items():
                                current_count += 1
                                node = plant_data.get('sensorNode')
                                if node in nodes:
                                    log_with_timestamp(f"식물 분석 시작 ({current_count}/{total_plants}) - ID: {plant_id}, Node: {node}")
                                    monitor.process_plant(node, plant_id)
                        
                        log_with_timestamp("모든 식물 분석 완료")
                    
                    # 트리거 초기화
                    log_with_timestamp("트리거 초기화 중...")
                    db.reference('ai_monitoring/trigger').set({})
                    log_with_timestamp("트리거 초기화 완료")
                    
                except Exception as e:
                    log_with_timestamp(f"분석 중 오류 발생: {e}")
                    db.reference('ai_monitoring/trigger').set({})
        
        db.reference('ai_monitoring/trigger').listen(handle_trigger)
        log_with_timestamp("식물 건강 모니터링 시작...")
        
        # 무한 루프는 유지하되 schedule은 제거
        while True:
            time.sleep(1)

if __name__ == "__main__":
    main() 