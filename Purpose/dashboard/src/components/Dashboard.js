import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { supabase } from '../supabaseClient';
import { useNavigate } from 'react-router-dom';
import { TextField, Button, Card, CardContent } from '@mui/material';
import KPIExport from './KPIExport';

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

  return (
    <div style={{ padding: '2rem' }}>
      <h2>AcumenIQ Dashboard</h2>
      <div>
        <TextField
          type="date"
          value={selectedDate}
          onChange={handleDateChange}
        />
        <Button variant="contained" onClick={fetchData}>Load Data</Button>
      </div>
      <div style={{ display: 'flex', marginTop: '1rem', gap: '1rem' }}>
        {data.map((item, index) => (
          <Card key={index} style={{ minWidth: '200px' }}>
            <CardContent>
              <h3>{item.program}</h3>
              <p>Census: {item.census}</p>
              <p>Admissions: {item.admissions}</p>
              <p>Transfers: {item.transfers}</p>
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
