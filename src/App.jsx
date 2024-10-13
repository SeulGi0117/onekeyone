import React from 'react';
import { BrowserRouter as Router, Route, Routes } from 'react-router-dom';
import PlantList from './components/PlantList';
import AddPlant from './components/AddPlant';

function App() {
  return (
    <Router>
      <Routes>
        <Route path="/" element={<PlantList />} />
        <Route path="/add-plant" element={<AddPlant />} />
      </Routes>
    </Router>
  );
}

export default App;
