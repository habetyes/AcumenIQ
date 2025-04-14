import React, { useState, useEffect } from 'react';
import { supabase } from '../supabaseClient';
import { Bar } from 'react-chartjs-2';
import GaugeChart from 'react-gauge-chart'
import { Chart, BarElement, CategoryScale, LinearScale, Title, Tooltip, Legend } from 'chart.js';
import { TextField, Button, MenuItem } from '@mui/material';
import DataTable from 'react-data-table-component';
import '../styles.css'; // Import the CSS file

Chart.register(BarElement, CategoryScale, LinearScale, Title, Tooltip, Legend);

// get yesterday's date in YYYY-MM-DD format
const yesterday = new Date(Date.now() - 86400000).toISOString().split('T')[0];
// get 7 days ago in YYYY-MM-DD format
const sevenDaysAgo = new Date(Date.now() - 604800000).toISOString().split('T')[0];

function DischargeTrends() {
  const [startDate, setStartDate] = useState(sevenDaysAgo);
  const [endDate, setEndDate] = useState(yesterday);
  const [selectedPrograms, setSelectedPrograms] = useState(['Detox', 'Residential', 'SUD IOP', 'Psych IOP', 'Aftercare']);
  const [chartData, setChartData] = useState({});
  const [tableData, setTableData] = useState([]);
  const [gaugeData, setGaugeData] = useState({});
  const [totals, setTotals] = useState({ total: 0, ama: 0, admin: 0, successful: 0 });

  const programOptions = ['Detox', 'Residential', 'SUD IOP', 'Psych IOP', 'Aftercare'];

  const fetchTrends = async () => {
    let query = supabase.from('vw_discharges')
      .select('casefile_id, full_name, discharge_class, program_category, discharge_date')
      .gte('discharge_date', startDate)
      .lte('discharge_date', endDate);

    if (selectedPrograms.length > 0) {
      query = query.in('program_category', selectedPrograms);
    }

    const { data, error } = await query;
    if (error) {
      console.error('Error fetching trends:', error);
    } else {
      // Calculate totals
      const total = data.length;
      const ama = data.filter(item => item.discharge_class === 'AMA').length;
      const admin = data.filter(item => item.discharge_class === 'Admin').length;
      const successful = data.filter(item => item.discharge_class === 'Successful').length;

      setTotals({ total, ama, admin, successful });

      // Prepare data for the stacked bar chart
      const programCategories = [...new Set(data.map(item => item.program_category))];
      const dischargeClasses = ['AMA', 'Admin', 'Successful'];

      const datasets = dischargeClasses.map(dischargeClass => ({
        label: dischargeClass,
        data: programCategories.map(category => {
          const count = data.filter(item => item.program_category === category && item.discharge_class === dischargeClass).length;
          const totalForCategory = data.filter(item => item.program_category === category).length;
          return totalForCategory > 0 ? (count / totalForCategory) * 100 : 0;
        }),
        backgroundColor: dischargeClass === 'AMA' ? 'red' : dischargeClass === 'Admin' ? 'orange' : 'green',
      }));

      setChartData({
        labels: programCategories,
        datasets: datasets,
      });

      // Prepare data for the table
      setTableData(data);

      // Prepare data for the gauge charts
      setGaugeData({
        ama: (ama / total) * 100,
        admin: (admin / total) * 100,
        successful: (successful / total) * 100,
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
        <TextField
          label="Programs"
          select
          SelectProps={{
            multiple: true,
            value: selectedPrograms,
            onChange: (e) => setSelectedPrograms(e.target.value),
          }}
          variant="outlined"
          style={{ marginLeft: '1rem' }}
        >
          {programOptions.map((program) => (
            <MenuItem key={program} value={program}>
              {program}
            </MenuItem>
          ))}
        </TextField>
        <Button variant="contained" onClick={fetchTrends} style={{ marginLeft: '1rem' }}>
          Load Trends
        </Button>
      </div>

      <div style={{ marginTop: '2rem' }}>
        <h3>Metrics</h3>
        <p>Total Discharges: {totals.total}</p>
        <p>AMA Discharges: {totals.ama} ({((totals.ama / totals.total) * 100).toFixed(1)}%)</p>
        <p>Admin Discharges: {totals.admin} ({((totals.admin / totals.total) * 100).toFixed(1)}%)</p>
        <p>Successful Discharges: {totals.successful} ({((totals.successful / totals.total) * 100).toFixed(1)}%)</p>
      </div>

      <div style={{ marginTop: '2rem' }}>
        <h3>Stacked 100% Bar Chart</h3>
        {chartData.labels ? (
          <Bar
            data={chartData}
            options={{
              plugins: {
                tooltip: { enabled: true },
                legend: { position: 'top' },
                datalabels: { display: true, formatter: value => `${value.toFixed(1)}%` },
              },
              responsive: true,
              scales: {
                x: { stacked: true },
                y: { stacked: true, ticks: { callback: value => `${value}%` } },
              },
            }}
          />
        ) : (
          <p>No data available</p>
        )}
      </div>

      <div style={{ marginTop: '2rem' }}>
        <h3>Data Table</h3>
        <DataTable
          columns={[
            { name: 'Casefile ID', selector: row => row.casefile_id },
            { name: 'Full Name', selector: row => row.full_name },
            { name: 'Discharge Class', selector: row => row.discharge_class },
            { name: 'Program Category', selector: row => row.program_category },
            { name: 'Discharge Date', selector: row => row.discharge_date },
          ]}
          data={tableData}
          pagination
        />
      </div>

      <div style={{ marginTop: '2rem' }}>
        <h3>Gauge Charts</h3>
        <div style={{ display: 'flex', justifyContent: 'space-around' }}>
          {['ama', 'admin', 'successful'].map(type => (
            <div key={type}>
              <GaugeChart
                value={gaugeData[type]}
                max={100}
                label={`${type.toUpperCase()} (${gaugeData[type]?.toFixed(1)}%)`}
                target={type === 'ama' ? 20 : type === 'admin' ? 10 : 70}
              />
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

export default DischargeTrends;