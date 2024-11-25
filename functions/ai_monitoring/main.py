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

class PlantHealthMonitor:
    def __init__(self):
        # Firebase 초기화
        cred = credentials.Certificate("./functions/src/model/firebase-adminsdk.json")
        firebase_admin.initialize_app(cred, {
            'databaseURL': 'https://aaaa-8a6a5-default-rtdb.firebaseio.com'
        })

        # 상수 정의
        self.DEVICE = torch.device("cpu")
        self.YOLO_MODEL_PATH = "./functions/src/model/last_yolo.pt"
        self.EFFICIENT_MODEL_PATH = "./functions/src/model/efficient_best_loss_model_0.0157.pt"
        
        # 모델 로드
        self.yolo_model = torch.hub.load('ultralytics/yolov5', 'custom', 
                                       path=self.YOLO_MODEL_PATH, device=self.DEVICE)
        self.efficient_model = self.load_efficient_model()
        
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
            return image
        except Exception as e:
            print(f"이미지 가져오기 실패: {e}")
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
        except Exception as e:
            print(f"상태 업데이트 실패: {e}")

    def process_plant(self, node_path, plant_id):
        """단일 식물 처리"""
        try:
            # 이미지 가져오기
            image = self.get_image_from_firebase(node_path)
            if image is None:
                return
            
            # YOLO 분석
            results = self.analyze_with_yolo(image)
            if results is None:
                return
            
            # Unhealthy 잎 확인
            unhealthy_results = results[results['name'].str.lower() == 'unhealthy']
            
            if not unhealthy_results.empty:
                # 첫 번째 unhealthy 잎 크롭
                first_unhealthy = unhealthy_results.iloc[0]
                bbox = [int(first_unhealthy[c]) for c in ['xmin', 'ymin', 'xmax', 'ymax']]
                
                cropped = image.crop(bbox)
                crop_path = f"temp_crop_{plant_id}.jpg"
                cropped.save(crop_path)
                
                # 질병 분석
                disease = self.analyze_disease(crop_path)
                os.remove(crop_path)  # 임시 파일 삭제
                
                self.update_plant_status(plant_id, "unhealthy", disease)
            else:
                self.update_plant_status(plant_id, "healthy")
                
        except Exception as e:
            print(f"식물 처리 중 오류 발생: {e}")

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
                        
        except Exception as e:
            print(f"전체 식물 체크 중 오류 발생: {e}")

def main():
    monitor = PlantHealthMonitor()
    
    # 30분마다 실행
    schedule.every(30).minutes.do(monitor.check_all_plants)
    
    print("식물 건강 모니터링 시작...")
    while True:
        schedule.run_pending()
        time.sleep(1)

if __name__ == "__main__":
    main() 