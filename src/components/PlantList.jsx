import React from 'react';
import { useNavigate } from 'react-router-dom';

function PlantList() {
  const navigate = useNavigate();

  const handleAddPlant = () => {
    navigate('/add-plant');
  };

  return (
    <div>
      {/* 기존 코드... */}
      <button onClick={handleAddPlant}>식물 추가하기</button>
      {/* 기존 코드... */}
    </div>
  );
}

export default PlantList;
