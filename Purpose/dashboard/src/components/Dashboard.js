import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { supabase } from '../supabaseClient';
import { useNavigate } from 'react-router-dom';
import { TextField, Button, Card, CardContent } from '@mui/material';
import KPIExport from './KPIExport';
import '../styles.css'; // Import the CSS file

function Dashboard() {
  const [selectedDate, setSelectedDate] = useState('');
  const [data, setData] = useState([]);
  const [programs, setPrograms] = useState([]);
  const navigate = useNavigate();

  useEffect(() => {
    // Check if user is logged in
    supabase.auth.getSession().then(({ data: { session } }) => {
      if (!session) {
        navigate('/login');
      }
    });
  }, [navigate]);

  const fetchData = async () => {
    // Fetch KPI data from the Supabase materialized view filtering by the selected date
    const { data: kpiData, error } = await supabase
      .from('vw_daily_census')
      .select('*')
      .eq('census_date', selectedDate);
    if (error) {
      console.error('Error fetching KPI data:', error);
    } else {
      setData(kpiData);
      // Extract unique programs from the data for filter options
      const uniquePrograms = [...new Set(kpiData.map(item => item.program))];
      setPrograms(uniquePrograms);
    }
  };

  const handleDateChange = (e) => {
    setSelectedDate(e.target.value);
  };

  useEffect(() => {
    if (selectedDate) {
      fetchData(); // Fetch data after the date is updated
    }
  }, [selectedDate]); // Runs whenever selectedDate changes
  
  const incrementDate = () => {
    if (selectedDate) {
      const [year, month, day] = selectedDate.split('-').map(Number);
      const newDate = new Date(year, month - 1, day); // Create a UTC date
      newDate.setDate(newDate.getDate() + 1); // Increment the day in UTC
      const updatedDate = newDate.toISOString().split('T')[0]; // Format back to YYYY-MM-DD
      setSelectedDate(updatedDate); // Trigger state update
    }
  };
  
  const decrementDate = () => {
    if (selectedDate) {
      const [year, month, day] = selectedDate.split('-').map(Number);
      const newDate = new Date(year, month - 1, day); // Create a local date
      newDate.setDate(newDate.getDate() - 1); // Decrement the day
      const updatedDate = newDate.toISOString().split('T')[0]; // Format back to YYYY-MM-DD
      setSelectedDate(updatedDate); // Trigger state update
    }
  };

  const calculateTotals = (data) => {
    return data.reduce(
      (totals, item) => {
        totals.census += item.census || 0;
        totals.admissions += item.admissions || 0;
        totals.transfer_in += item.transfer_in || 0;
        totals.transfer_out += item.transfer_out || 0;
        totals.discharges += item.discharges || 0;
        return totals;
      },
      { census: 0, admissions: 0, transfer_in: 0, transfer_out: 0, discharges: 0 }
    );
  };

  const totals = calculateTotals(data);

  const desiredOrder = ["Detox", "Residential", "SUD IOP", "Psych IOP", "Aftercare"];

  const sortedData = [...data].sort((a, b) => {
    return desiredOrder.indexOf(a.program_category) - desiredOrder.indexOf(b.program_category);
  });

  return (
    <div className="dashboard-container">
      <h2>Purpose: Daily Census</h2>
      <div className="dashboard-controls">
        <TextField
          type="date"
          value={selectedDate}
          onChange={handleDateChange}
        />
        <Button variant="outlined" onClick={decrementDate}>Previous Day</Button>
        <Button variant="outlined" onClick={incrementDate}>Next Day</Button>
      </div>
      <div className="dashboard-totals">
        <p>Census: {totals.census}</p>
        <p>Admissions: {totals.admissions}</p>
        <p>Transfers In: {totals.transfer_in}</p>
        <p>Transfers Out: {totals.transfer_out}</p>
        <p>Discharges: {totals.discharges}</p>
      </div>
      <div className="dashboard-cards">
        {/* Individual Program Cards */}
        {sortedData.map((item, index) => (
          <Card key={index} className="card program-card">
            <CardContent>
              <h3>{item.program_category}</h3>
              <p>Census: {item.census}</p>
              <p>Admissions: {item.admissions}</p>
              <p>Transfers In: {item.transfer_in}</p>
              <p>Transfers Out: {item.transfer_out}</p>
              <p>Discharges: {item.discharges}</p>
            </CardContent>
          </Card>
        ))}
      </div>
      {data.length > 0 && <KPIExport data={data} />}
    </div>
  );
}

export default Dashboard;
