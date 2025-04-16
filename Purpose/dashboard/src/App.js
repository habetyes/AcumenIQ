import React from 'react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import Login from './components/Login';
import DischargeTrends from './components/DischargeTrends';
import Census from './components/Census';
import CensusTrends from './components/CensusTrends';
import Header from './components/Header';

function App() {
  return (
    <Router>
      <div>
        {/* Conditionally render Header */}
        {window.location.pathname !== '/login' && <Header />}
        <Routes>
          <Route path="/login" element={<Login />} />
          <Route path="/dischargetrends" element={<DischargeTrends />} />
          <Route path="/census" element={<Census />} />
          <Route path="/censustrends" element={<CensusTrends />} />
          <Route path="*" element={<Login />} />
        </Routes>
      </div>
    </Router>
  );
}

export default App;
