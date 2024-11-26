import firebase_admin
from firebase_admin import credentials
from firebase_admin import db
import csv
import os
import json

# Firebase 초기화
try:
    # 기존 앱이 있다면 삭제
    for app in firebase_admin._apps:
        firebase_admin.delete_app(firebase_admin.get_app(app))
except:
    pass

# 서비스 계정 키 파일 경로
key_path = 'D:/my_plant/functions/src/model/aaaa-8a6a5-firebase-adminsdk-1wmfe-d3f93bba70.json'

# 서비스 계정 키 파일 읽기
with open(key_path) as f:
    service_account_info = json.load(f)

cred = credentials.Certificate(service_account_info)
firebase_admin.initialize_app(cred, {
    'databaseURL': 'https://aaaa-8a6a5-default-rtdb.firebaseio.com/'
})

def upload_disease_data():
    try:
        # CSV 파일 읽기
        csv_path = 'D:/my_plant/functions/ai_monitoring/plants_class_data.csv'
        
        with open(csv_path, 'r', encoding='utf-8-sig') as file:
            csv_reader = csv.DictReader(file)
            
            # Firebase reference
            ref = db.reference('plant_diseases')
            
            # 데이터를 한 번에 업로드하기 위한 딕셔너리
            all_diseases = {}
            
            for row in csv_reader:
                try:
                    # 영문 병명에서 공백을 _로 변환하여 키로 사용
                    disease_key = row['병명 (영어)'].strip().replace(' ', '_')
                    
                    # 처방전 리스트를 문자열로 결합
                    prescriptions = []
                    for i in range(1, 4):
                        prescription = row.get(f'처방전 {i}')
                        if prescription and prescription.strip():
                            prescriptions.append(prescription.strip())
                    
                    # 데이터 구조화
                    disease_data = {
                        '한국어_병명': row['병명 (한국어)'].strip(),
                        '증상': row['증상'].strip(),
                        '원인': row.get('원인', '').strip(),
                        '처방전': '\n'.join(prescriptions)
                    }
                    
                    # 딕셔너리에 추가
                    all_diseases[disease_key] = disease_data
                    print(f'Processed: {disease_key}')
                    
                except KeyError as e:
                    print(f'Error processing row: {row}')
                    print(f'Missing key: {e}')
                    continue
                except Exception as e:
                    print(f'Error processing {disease_key}: {e}')
                    continue
            
            # 과습 데이터 추가
            all_diseases['plant___overwartering'] = {
                '한국어_병명': '과습',
                '증상': '잎의 색이 가장자리부터 노란색으로 빠짐\n화분이 오래동안 젖어있고, 흙이 마르는 속도가 굉장히 느림\n물을 주어도 식물이 축 늘어지며 시듬',
                '원인': '흙이 다 마르지 않았는 데 물을 준 적이 있는 경우\n물이 고인 상태로 화분을 물받침 위에 올려둔 경우\n물을 주었을 때, 화분 구멍 밑으로 물이 잘 빠져나오지 않을 경우',
                '처방전': '화분 위 흙에 덮인 자식 돌(마사토 등)을 치워 흙 표면을 통한 수분 증발이 원할하게 되도록 도와주세요.\n흙 곳곳에 손가락이나 나무젓가락 등으로 구멍을 뚫어 안 쪽까지 통기가 잘 되도록 도와주세요. 너무 세게 찌르면 뿌리를 다칠 수 있으니 주의해요.\n물 받침에 고인 물은 바로바로 제거해주세요.\n저면관수 화분의 경우, 화분이 과하게 젖지 않도록 물의 양을 조절해 담아주세요.\n화분 밑에 병뚜껑 등을 깔아 화분 밑 구멍과 바닥 사이의 공간을 띄워주어 미틍로 바람이 잘 통하게 도와주세요\n물을 주어도 물이 잘 빠지지 않을 경우 알갱이가 큰 재료를 많이 섞어 새로 분갈이를 해주세요.'
            }
            
            # 한 번에 모든 데이터 업로드
            ref.set(all_diseases)
            print('Successfully uploaded all disease data')
            
    except Exception as e:
        print(f'Error: {e}')

if __name__ == '__main__':
    try:
        # CSV 파일의 헤더 출력
        csv_path = 'D:/my_plant/functions/ai_monitoring/plants_class_data.csv'
        with open(csv_path, 'r', encoding='utf-8-sig') as file:
            reader = csv.reader(file)
            headers = next(reader)
            print("CSV Headers:", headers)
        
        upload_disease_data()
    except Exception as e:
        print(f'Error: {e}') 