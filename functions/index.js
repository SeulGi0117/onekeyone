const { initializeApp } = require('firebase-admin/app');
const { getDatabase } = require('firebase-admin/database');
const { https } = require('firebase-functions/v1');
const { PythonShell } = require('python-shell');
const path = require('path');

initializeApp();

exports.runPlantAnalysis = https.onCall(async (data, context) => {
  const { plantId, sensorNode } = data;
  
  try {
    // Firebase Realtime Database에 트리거 설정
    const db = getDatabase();
    const triggerRef = db.ref('ai_monitoring/trigger');
    await triggerRef.set({
      plantId: plantId,
      sensorNode: sensorNode,
      requestType: 'manual',
      timestamp: admin.database.ServerValue.TIMESTAMP,
      status: 'pending'
    });

    // 분석 완료 대기 (최대 30초)
    let attempts = 0;
    const maxAttempts = 30;
    
    while (attempts < maxAttempts) {
      const snapshot = await triggerRef.once('value');
      const triggerData = snapshot.val();
      
      if (!triggerData || Object.keys(triggerData).length === 0) {
        return { 
          success: true, 
          message: '식물 상태 분석이 완료되었습니다.',
          status: 'completed'
        };
      }
      
      await new Promise(resolve => setTimeout(resolve, 1000));
      attempts++;
    }
    
    throw new Error('분석 시간 초과');

  } catch (error) {
    console.error('실행 오류:', error);
    throw new https.HttpsError('internal', 
      `분석 중 오류가 발생했습니다: ${error.message}`);
  }
}); 