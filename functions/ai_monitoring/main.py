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

class PlantHealthMonitor:
    def __init__(self):
        # Firebase 초기화
        cred = credentials.Certificate(r"D:/my_plant/functions/src/model/aaaa-8a6a5-firebase-adminsdk-1wmfe-d3f93bba70.json")
        firebase_admin.initialize_app(cred, {
            'databaseURL': 'https://aaaa-8a6a5-default-rtdb.firebaseio.com'
        })

        # 상수 정의
        self.DEVICE = torch.device("cpu")
        self.YOLO_MODEL_PATH = os.path.abspath("./functions/src/model/last_yolo.pt")
        self.EFFICIENT_MODEL_PATH = os.path.abspath("./functions/src/model/efficient_best_loss_model_0.0157.pt")
        
        # Windows에서 PosixPath 오류 해결을 위한 패치
        if platform.system() == 'Windows':
            import pathlib
            temp = pathlib.PosixPath
            pathlib.PosixPath = pathlib.WindowsPath
        
        # 모델 로드
        try:
            print("YOLO 모델 로딩 시작...")
            self.yolo_model = torch.hub.load('ultralytics/yolov5', 'custom', 
                                           path=self.YOLO_MODEL_PATH, 
                                           device=self.DEVICE,
                                           force_reload=True)  # force_reload 추가
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

    def process_plant(self, node_path, plant_id):
        """단일 식물 처리"""
        try:
            print(f"\n{'='*50}")
            print(f"식물 ID: {plant_id} 분석 프로세스 시작")
            print(f"센서 노드: {node_path}")
            
            # 이미지 가져오기
            print("\n1. 실시간 이미지 가져오기 시작...")
            image = self.get_image_from_firebase(node_path)
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
        """모든 식물 체크"""
        try:
            nodes = ['JSON', 'JSON2', 'JSON3']
            plants_ref = db.reference('plants')
            plants = plants_ref.get()
            
            if plants:
                for plant_id, plant_data in plants.items():
                    node = plant_data.get('sensorNode')
                    if node in nodes:
                        self.process_plant(node, plant_id)
            print("모든 식물 체크 완료")
                        
        except Exception as e:
            print(f"전체 식물 체크 중 오류 발생: {e}")

def main():
    monitor = PlantHealthMonitor()
    
    # 트리거 감시
    def handle_trigger(event):
        if event.data:
            trigger_data = event.data
            plant_id = trigger_data.get('plantId')
            sensor_node = trigger_data.get('sensorNode')
            request_type = trigger_data.get('requestType')
            
            print(f"\n{'='*50}")
            print(f"분석 요청 감지!")
            print(f"요청 유형: {request_type}")
            print(f"Plant ID: {plant_id}")
            print(f"센서 노드: {sensor_node}")
            print(f"요청 시간: {trigger_data.get('timestamp')}")
            print(f"{'='*50}\n")
            
            if plant_id and sensor_node:
                print(f"식물 분석 시작...")
                monitor.process_plant(sensor_node, plant_id)
                
                # 트리거 초기화 - None 대신 빈 딕셔너리 사용
                print("트리거 초기화 중...")
                db.reference('ai_monitoring/trigger').set({})
                print("트리거 초기화 완료")
            else:
                print("필수 정보 누락: plant_id 또는 sensor_node가 없습니다.")
    
    # 트리거 리스너 설정
    db.reference('ai_monitoring/trigger').listen(handle_trigger)
    
    # 30분마다 자동 실행
    schedule.every(30).minutes.do(monitor.check_all_plants)
    
    print("식물 건강 모니터링 시작...")
    while True:
        schedule.run_pending()
        time.sleep(1)

if __name__ == "__main__":
    main() 