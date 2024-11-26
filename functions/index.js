const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { spawn } = require('child_process');
const path = require('path');

admin.initializeApp();

exports.runPlantAnalysis = functions.region('asia-northeast3').https.onCall(async (data, context) => {
  const { plantId, sensorNode } = data;
  
  try {
    // AI 모니터링 트리거 설정
    await admin.database().ref('ai_monitoring/trigger').set({
      plantId: plantId,
      sensorNode: sensorNode,
      requestType: 'manual',
      timestamp: admin.database.ServerValue.TIMESTAMP
    });

    // Python 스크립트 실행
    const pythonProcess = spawn('python', [
      path.join(__dirname, 'ai_monitoring/main.py')
    ]);

    // Python 스크립트의 출력 로깅
    pythonProcess.stdout.on('data', (data) => {
      console.log(`Python 출력: ${data}`);
    });

    pythonProcess.stderr.on('data', (data) => {
      console.error(`Python 오류: ${data}`);
    });

    // Python 프로세스 완료 대기
    await new Promise((resolve, reject) => {
      pythonProcess.on('close', (code) => {
        if (code === 0) {
          resolve();
        } else {
          reject(new Error(`Python 프로세스 종료 코드: ${code}`));
        }
      });
    });

    return { success: true, message: '분석이 완료되었습니다.' };
  } catch (error) {
    console.error('분석 오류:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
}); 