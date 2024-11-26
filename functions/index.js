const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { PythonShell } = require('python-shell');
const path = require('path');

admin.initializeApp();

exports.runPlantAnalysis = functions
  .region('asia-northeast3')
  .https.onCall(async (data, context) => {
    const { plantId, sensorNode } = data;
    
    try {
      // AI 모니터링 트리거 설정
      const triggerRef = admin.database().ref('ai_monitoring/trigger');
      
      await triggerRef.set({
        plantId: plantId,
        sensorNode: sensorNode,
        requestType: 'manual',
        timestamp: admin.database.ServerValue.TIMESTAMP,
        status: 'pending'
      });

      // Python 스크립트 실행
      const options = {
        mode: 'text',
        pythonPath: 'python3',
        pythonOptions: ['-u'],
        scriptPath: path.join(__dirname, 'ai_monitoring'),
        args: [plantId, sensorNode]
      };

      // Python 스크립트 실행 및 결과 대기
      await new Promise((resolve, reject) => {
        PythonShell.run('main.py', options, function (err) {
          if (err) reject(err);
          resolve();
        });
      });

      // 분석 완료를 기다림 (최대 30초)
      let attempts = 0;
      const maxAttempts = 30;
      
      while (attempts < maxAttempts) {
        await new Promise(resolve => setTimeout(resolve, 1000));
        
        const snapshot = await triggerRef.once('value');
        const triggerData = snapshot.val();
        
        if (!triggerData || Object.keys(triggerData).length === 0) {
          return { success: true, message: '분석이 완료되었습니다.' };
        }
        
        attempts++;
      }
      
      throw new Error('분석 시간 초과');
    } catch (error) {
      console.error('분석 오류:', error);
      throw new functions.https.HttpsError('internal', error.message);
    }
}); 