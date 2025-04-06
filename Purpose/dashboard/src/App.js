import React from 'react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import Login from './components/Login';
import Dashboard from './components/Dashboard';
import DischargeTrends from './components/DischargeTrends';

function App() {
  return (
    <Router>
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route path="/dashboard" element={<Dashboard />} />
        <Route path="/trends" element={<DischargeTrends />} />
        <Route path="*" element={<Login />} />
      </Routes>
    </Router>
  );
}

export default App;
