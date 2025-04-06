import React, { useState, useEffect } from 'react';
import { supabase } from '../supabaseClient';
import { Line } from 'react-chartjs-2';
import { Chart, LineElement, PointElement, LinearScale, Title, CategoryScale } from 'chart.js';
import { TextField, Button } from '@mui/material';
import { useNavigate } from 'react-router-dom';

Chart.register(LineElement, PointElement, LinearScale, Title, CategoryScale);

function DischargeTrends() {
  const [startDate, setStartDate] = useState('');
  const [endDate, setEndDate] = useState('');
  const [selectedPrograms, setSelectedPrograms] = useState([]);
  const [chartData, setChartData] = useState({});
  const navigate = useNavigate();

  useEffect(() => {
    supabase.auth.getSession().then(({ data: { session } }) => {
      if (!session) {
        navigate('/login');
      }
    });
  }, [navigate]);

  const fetchTrends = async () => {
    // Fetch discharge trends data filtered by date range and selected programs
    let query = supabase.from('mv_discharge_trends')
      .select('*')
      .gte('date', startDate)
      .lte('date', endDate);

    if (selectedPrograms.length > 0) {
      query = query.in('program', selectedPrograms);
    }

    const { data, error } = await query;
    if (error) {
      console.error('Error fetching trends:', error);
    } else {
      // Process data for chart.js
      const dates = [...new Set(data.map(item => item.date))].sort();
      const dischargeTypes = [...new Set(data.map(item => item.discharge_type))];
      
      const datasets = dischargeTypes.map(type => ({
        label: type,
        data: dates.map(date => {
          const record = data.find(item => item.date === date && item.discharge_type === type);
          return record ? record.count : 0;
        }),
        fill: false
      }));

      setChartData({
        labels: dates,
        datasets: datasets,
      });
    }
  };

  return (
    <div style={{ padding: '2rem' }}>
      <h2>Discharge Trends</h2>
      <div>
        <TextField
          type="date"
          label="Start Date"
          value={startDate}
          onChange={(e) => setStartDate(e.target.value)}
        />
        <TextField
          type="date"
          label="End Date"
          value={endDate}
          onChange={(e) => setEndDate(e.target.value)}
        />
        {/* A multi-select dropdown for programs could be added here */}
        <Button variant="contained" onClick={fetchTrends}>Load Trends</Button>
      </div>
      <div style={{ marginTop: '2rem' }}>
        {chartData.labels ? <Line data={chartData} /> : <p>No data available</p>}
      </div>
    </div>
  );
}

export default DischargeTrends;
