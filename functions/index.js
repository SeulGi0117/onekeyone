const { initializeApp } = require('firebase-admin/app');
const { getDatabase } = require('firebase-admin/database');
const { https } = require('firebase-functions/v1');
const { PythonShell } = require('python-shell');
const path = require('path');

initializeApp();

exports.runPlantAnalysis = https.onCall(async (data, context) => {
  const { plantId, sensorNode } = data;
  
  try {
    // 1. Firebase Realtime Database에 트리거 설정
    const db = getDatabase();
    const triggerRef = db.ref('ai_monitoring/trigger');
    await triggerRef.set({
      plantId: plantId,
      sensorNode: sensorNode,
      requestType: 'manual',
      timestamp: admin.database.ServerValue.TIMESTAMP,
      status: 'pending'
    });

    // 2. Python 스크립트 실행
    const options = {
      mode: 'text',
      pythonPath: 'python',
      pythonOptions: ['-u'],
      scriptPath: path.join(__dirname, 'ai_monitoring'),
      args: [plantId, sensorNode]
    };

    try {
      await new Promise((resolve, reject) => {
        PythonShell.run('main.py', options, function (err, results) {
          if (err) {
            console.error('Python 스크립트 실행 오류:', err);
            reject(err);
          }
          console.log('Python 스크립트 실행 결과:', results);
          resolve(results);
        });
      });

      // 분석 완료 확인
      const snapshot = await triggerRef.once('value');
      const triggerData = snapshot.val();
      
      if (!triggerData || Object.keys(triggerData).length === 0) {
        return { 
          success: true, 
          message: '분석이 완료되었습니다.',
          status: 'completed'
        };
      }
      
      return {
        success: false,
        message: '분석 처리 중 오류가 발생했습니다.',
        status: 'error'
      };

    } catch (pythonError) {
      console.error('Python 실행 오류:', pythonError);
      throw new https.HttpsError('internal', 
        `Python 스크립트 실행 오류: ${pythonError.message}`);
    }

  } catch (error) {
    console.error('전체 실행 오류:', error);
    throw new https.HttpsError('internal', 
      `분석 중 오류가 발생했습니다: ${error.message}`);
  }
}); 