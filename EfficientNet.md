# EfficientNet을 활용한 건강한 잎과 병든 잎 분류 모델 만들기

건강한 잎과 병든 잎을 분류하는 인공지능 모델을 **EfficientNet**을 사용해 구축하는 과정은 여러 단계로 나뉩니다. 여기서는 **TensorFlow**와 **EfficientNet**을 사용해 이 프로젝트를 어떻게 진행하면 좋을지 단계별로 설명하겠습니다.

## 1. 데이터 준비
먼저 **건강한 잎**과 **병든 잎**의 이미지를 포함한 데이터셋을 준비해야 합니다. 데이터는 이미 라벨링되어 있어야 하고, **이미지 크기**, **형식**이 일정해야 합니다. 데이터셋은 주로 다음과 같은 두 가지 클래스가 존재합니다:

- **건강한 잎**
- **병든 잎**

### 1.1 데이터셋 불러오기
TensorFlow에서는 이미지 데이터를 쉽게 불러올 수 있는 유틸리티 함수를 제공합니다.

```python
import tensorflow as tf
from tensorflow.keras.preprocessing import image_dataset_from_directory

# 이미지가 저장된 디렉토리로부터 데이터셋을 불러오기
dataset = image_dataset_from_directory(
    'path_to_leaf_dataset',  # 데이터셋의 경로
    image_size=(224, 224),   # EfficientNet이 요구하는 이미지 크기
    batch_size=32,           # 배치 사이즈
    label_mode='int'         # 클래스 라벨을 정수형으로 가져옴
)
```
## 2. EfficientNet 모델 불러오기
EfficientNet은 TensorFlow와 Keras에서 사전 학습된(pretrained) 모델을 쉽게 불러올 수 있습니다. EfficientNet을 사용할 때 **전이 학습(Transfer Learning)** 을 활용하는 것이 효율적입니다. 즉, 이미 ImageNet 데이터셋으로 학습된 EfficientNet 모델을 가져와 마지막 층만 우리의 문제에 맞게 다시 학습시키는 방식입니다.

### 2.1 EfficientNet 모델 로드 및 미세 조정(Transfer Learning)
TensorFlow에서는 EfficientNet을 가져와 필요한 부분만 미세 조정할 수 있습니다.
```python
from tensorflow.keras.applications import EfficientNetB0
from tensorflow.keras.layers import GlobalAveragePooling2D, Dense
from tensorflow.keras.models import Model

# 사전 학습된 EfficientNetB0 모델 불러오기 (ImageNet으로 학습됨)
base_model = EfficientNetB0(weights='imagenet', include_top=False, input_shape=(224, 224, 3))

# 기존의 모든 레이어를 고정 (훈련되지 않음)
base_model.trainable = False

# 상단에 새로운 레이어 추가 (우리의 문제에 맞춤)
x = base_model.output
x = GlobalAveragePooling2D()(x)
x = Dense(128, activation='relu')(x)  # 추가된 레이어
output = Dense(2, activation='softmax')(x)  # 클래스가 두 개이므로 출력 노드는 2개

# 새로운 모델 생성
model = Model(inputs=base_model.input, outputs=output)
```
## 3. 모델 컴파일
모델을 컴파일할 때 **손실 함수(loss function)** 와 **최적화 알고리즘(optimizer)** 을 정의합니다. 이진 분류 문제이므로 binary_crossentropy 손실 함수나 두 클래스 이상이면 categorical_crossentropy를 사용합니다

```python
model.compile(optimizer='adam', 
              loss='sparse_categorical_crossentropy', 
              metrics=['accuracy'])
```

## 4. 모델 훈련
데이터셋을 EfficientNet 모델에 입력해 훈련을 시작합니다. 모델의 성능을 향상시키기 위해 **조기 종료(Early Stopping)** 와 학습률 감소(Learning Rate Scheduler) 등의 기법을 추가할 수 있습니다.

```python
# 모델 훈련
history = model.fit(
    dataset,
    epochs=20,
    validation_data=validation_dataset  # 검증 데이터도 제공
)
```

## 5. 모델 미세 조정
처음에는 EfficientNet의 사전 학습된 부분을 고정한 상태로 훈련을 하고, 이후 추가 학습이 필요하면 사전 학습된 레이어의 일부를 **미세 조정(fine-tuning)** 할 수 있습니다.
``` python
# 특정 레이어부터 다시 훈련
base_model.trainable = True

# 특정 레이어까지만 미세 조정
fine_tune_at = 100

for layer in base_model.layers[:fine_tune_at]:
    layer.trainable = False

# 모델 재컴파일 후 미세 조정 훈련
model.compile(optimizer=tf.keras.optimizers.Adam(1e-5),  # 더 낮은 학습률 사용
              loss='sparse_categorical_crossentropy', 
              metrics=['accuracy'])

# 다시 훈련
history_fine = model.fit(
    dataset,
    epochs=10,
    validation_data=validation_dataset
)
```
## 6. 모델 평가 및 테스트
모델이 학습된 후에는 테스트 데이터셋으로 모델을 평가하고 성능을 측정합니다.
```python
test_loss, test_acc = model.evaluate(test_dataset)
print(f"테스트 정확도: {test_acc * 100:.2f}%")
```

## 7. 모델 저장
``` python
model.save('efficientnet_leaf_model.h5')
```

## 8. 추가적인 작업
- 데이터 증강(Data Augmentation): 모델의 일반화 성능을 높이기 위해, 학습 데이터에 회전, 좌우 반전, 확대 등을 적용할 수 있습니다.
- 모델 최적화: 하이퍼파라미터 튜닝(배치 크기, 학습률 등)을 통해 모델의 성능을 더 높일 수 있습니다.
- 모델 평가: 혼동 행렬(Confusion Matrix)과 같은 평가 방법을 통해 모델의 세부 성능을 분석할 수 있습니다.
