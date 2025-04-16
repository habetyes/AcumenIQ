import React from 'react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import Login from './components/Login';
import DischargeTrends from './components/DischargeTrends';
import Census from './components/Census';
import CensusTrends from './components/CensusTrends';

function App() {
  return (
    <Router>
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route path="/trends" element={<DischargeTrends />} />
        <Route path="/census" element={<Census />} />
        <Route path="/censustrends" element={<CensusTrends />} />
        <Route path="*" element={<Login />} />
      </Routes>
    </Router>
  );
}

export default App;
