# 24-2-소프트웨어 캡스톤 디자인

 ## AI 기반 식물관리 어플리케이션

### 프로젝트 개요

부모님이 발령으로 주말에만 집에 오시는 상황에서, 여러 식물을 돌보는 책임을 맡게 되었으나, 식물에 대한 지식과 애정이 부족하고 동기부여가 약해 어려움을 겪고 있었다. 게임 속 캐릭터를 키우는 경험에서 영감을 받아, 식물 관리도 게임처럼 성취감을 느끼며 꾸준히 할 수 있는 시스템을 고안하게 되었다. 식물도 캐릭터처럼 관리가 필요하다는 점에서 유사성을 느꼈고, 이를 통해 건강하게 자라는 식물을 보며 성취감을 얻을 수 있을 것이라 기대했다. 이 프로젝트는 AI와 센서를 활용해 식물 상태를 실시간 모니터링하고, 캐릭터와의 상호작용을 통해 사용자가 식물 관리에 재미와 동기를 느낄 수 있도록 하는 것이 목표이다.

### 프로젝트의 목표 및 내용 (개발 목표)

이 프로젝트의 목표는 게임의 캐릭터처럼 사용자가 식물을 꾸준히 관리할 수 있는 시스템을 구축하는 것이다. AI와 센서를 결합한 IoT 기술을 활용하여, 사용자가 식물의 상태를 실시간으로 모니터링하고 적절한 조치를 취할 수 있도록 돕는다. 이를 통해 식물 관리의 효율성을 높이고, 게임적 요소를 통해 지속적인 동기부여를 제공하는 것이 최종 목표이다.

#### AI 기반 식물 분석 및 질병 예측
- **개발 목표**: 사용자가 촬영한 식물의 사진을 분석하여 해당 식물의 종을 자동으로 식별하고, 식물의 건강 상태를 AI 모델을 통해 분석하는 기능을 구현할 예정이다. 또한, 카메라로 식물의 상태를 분석해 질병을 예측하고, 이를 바탕으로 사용자에게 적절한 관리 조치를 제안한다. 
  - **식물 종 자동 식별**: PlantNet API와 Plant.id API를 사용하여 딥러닝 기반 이미지 분석을 통해 식물의 종을 자동으로 식별한다.
  - **질병 예측**: PlantVillage 데이터셋을 활용하여 TensorFlow 기반으로 EfficientNet 또는 ResNet 모델을 학습시켜, 식물 잎과 줄기 상태에서 질병을 예측하는 AI 모델을 개발한다.

#### 센서 기반 실시간 데이터 수집 및 관리
- **개발 목표**: 화분에 설치된 센서를 통해 수분, 온도, 습도 등의 실시간 데이터를 수집하고, 이를 바탕으로 식물의 상태를 모니터링하여 사용자가 적절한 관리를 할 수 있도록 돕는 기능을 구현한다.
  - **센서 연결 및 데이터 통신**: Arduino IoT 장치를 사용하여 다양한 센서(수분 센서, 온도 센서, 습도 센서, 토양 센서, 카메라)를 설치하고, 이 센서들이 수집한 데이터를 Wi-Fi 또는 Bluetooth를 통해 모바일 앱에 전송한다.
  - **실시간 데이터 모니터링**: 센서로부터 수집된 데이터를 실시간으로 시각화하여, 사용자가 모바일 앱에서 현재 식물의 상태(습도, 온도 등)를 쉽게 확인할 수 있도록 한다.
  - **경고 시스템**: 센서로 감지된 특정 조건(예: 습도가 특정 수준 이하로 떨어지면)에 따라 경고 알림을 전송해 사용자가 신속하게 식물을 돌볼 수 있게 한다.

#### 식물 관리 모바일 앱
- **개발 목표**: 사용자가 모바일 앱에서 식물의 상태를 관리하고, 식물의 건강 상태에 따라 상호작용하는 캐릭터를 통해 지속적인 관리 동기를 부여하는 시스템을 구현한다.
  - **모바일 앱 구현**: Vue.js를 사용해 반응형 모바일 인터페이스를 설계하여 사용자가 식물의 상태(습도, 온도 등)를 직관적으로 확인할 수 있도록 한다. Firebase는 실시간 데이터베이스로 센서 데이터를 저장하고 관리한다. 이를 통해 사용자는 센서로부터 수집된 데이터를 실시간으로 모니터링하고, 앱에서 식물 상태에 대한 피드백과 관리 정보를 제공받을 수 있다.
  - **게임 요소**: 사용자가 관리하는 식물을 캐릭터로 표현하며, 캐릭터가 식물의 상태에 따라 다양한 피드백을 제공한다. 사용자는 성공적인 관리 후 포인트를 획득하고, 캐릭터의 꾸미기 기능 등을 통해 게임 요소를 즐길 수 있다. 사용자가 성공적으로 식물을 관리하면 포인트를 획득하고, 캐릭터의 외형을 꾸미거나 추가 기능을 해금할 수 있다.

### 기대 효과 및 활용 방안
- **심리적 안정감 증대**: 반려식물의 관리 과정에서 사용자는 심리적 안정감과 감정 완화에 도움을 받으며, 우울증 해소에 기여할 수 있다.
- **식물 관리에 대한 지속적인 동기부여**: 게임적 요소와 보상 시스템을 통해 사용자가 지속적으로 식물을 관리할 수 있는 동기부여를 제공한다.
- **정보 접근성 향상**: 식물 관리에 필요한 정보 부족과 동기 부족으로 인해 양육을 포기하는 경우가 많은데, AI와 센서를 통해 실시간으로 식물 상태를 분석하여 사용자가 필요한 정보를 쉽게 얻고 적절한 관리를 할 수 있다.
- **환경적 긍정 효과**: 반려식물 양육을 통해 환경 보호와 관련된 긍정적인 효과를 기대할 수 있다.

## 추진 계획

| 세부내용                        | 수행기간(월) | 비고  |
|--------------------------------|-------------|-------|
| 1. 계획수립 및 자료조사          | 9           |       |
| 2. 모바일 어플리케이션 개발      | 9 ~ 11      |       |
| 3. 인공지능 모델 개발            | 9 ~ 11      |       |
| 4. 통합 테스트 및 유지보수        | 11 ~ 12     |       |

애자일 방식을 적용해 빠른 개발 주기를 유지하고, 주 2회 화요일(또는 수요일)과 금요일(또는 토요일)에 스프린트 미팅을 통해 작업 상황을 점검하며 진행한다. 스프린트 미팅에서는 각 작업 진행 상황을 공유하고 발생한 문제를 즉시 해결하며, 목표 달성을 위한 피드백을 빠르게 반영한다. AI 기반 식물 분석과 질병 예측을 구현하기 위해 딥러닝 모델 학습을 위한 주 1회 스터디를 진행하여 팀원들이 딥러닝 기술에 대한 이해도를 높인다. 팀원의 개발 역량 차이를 줄이기 위해, 모든 팀원이 Vue.js와 JavaScript를 함께 학습하며 앱 개발에 참여한다. 이를 통해 팀원들은 기본적인 프론트엔드 개발 능력을 습득하고, 효과적인 협업을 이어나간다.