import React, { useState, useEffect } from 'react';
import { supabase } from '../supabaseClient';
import { Bar } from 'react-chartjs-2';
import { Chart, BarElement, CategoryScale, LinearScale, Title, Tooltip, Legend } from 'chart.js';
import { TextField, Button, MenuItem } from '@mui/material';
import Table from '@mui/material/Table';
import TableBody from '@mui/material/TableBody';
import TableCell from '@mui/material/TableCell';
import TableContainer from '@mui/material/TableContainer';
import TableHead from '@mui/material/TableHead';
import TableRow from '@mui/material/TableRow';
import Paper from '@mui/material/Paper';
import TablePagination from '@mui/material/TablePagination';
import '../styles/DischargeTrends.css'; // Updated CSS file import

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
  const [totals, setTotals] = useState({ total: 0, ama: 0, admin: 0, successful: 0 });
  const [page, setPage] = useState(0);
  const [rowsPerPage, setRowsPerPage] = useState(10);

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
    }
  };

  const handleChangePage = (event, newPage) => {
    setPage(newPage);
  };

  const handleChangeRowsPerPage = (event) => {
    setRowsPerPage(parseInt(event.target.value, 10));
    setPage(0);
  };

  return (
    <div className="discharge-trends-container">
      <h2>Discharge Trends</h2>
      <div className="filters">
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
          className="program-select"
        >
          {programOptions.map((program) => (
            <MenuItem key={program} value={program}>
              {program}
            </MenuItem>
          ))}
        </TextField>
        <Button variant="contained" onClick={fetchTrends} className="load-trends-button">
          Load Trends
        </Button>
      </div>

      <div className="totals-row">
        <div>Total Discharges: {totals.total}</div>
        <div>AMA Discharges: {totals.ama} ({((totals.ama / totals.total) * 100).toFixed(1)}%)</div>
        <div>Admin Discharges: {totals.admin} ({((totals.admin / totals.total) * 100).toFixed(1)}%)</div>
        <div>Successful Discharges: {totals.successful} ({((totals.successful / totals.total) * 100).toFixed(1)}%)</div>
      </div>

      <div className="content-row">
        <div className="chart-container">
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

        <div className="table-container">
          <TableContainer component={Paper}>
            <Table size="small" aria-label="dense table">
              <TableHead>
                <TableRow>
                  <TableCell align="center">Casefile ID</TableCell>
                  <TableCell align="center">Full Name</TableCell>
                  <TableCell align="center">Discharge Class</TableCell>
                  <TableCell align="center">Program Category</TableCell>
                  <TableCell align="center">Discharge Date</TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {tableData
                  .slice(page * rowsPerPage, page * rowsPerPage + rowsPerPage)
                  .map((row, index) => (
                    <TableRow key={index}>
                      <TableCell align="center">{row.casefile_id}</TableCell>
                      <TableCell align="center">{row.full_name}</TableCell>
                      <TableCell align="center">{row.discharge_class}</TableCell>
                      <TableCell align="center">{row.program_category}</TableCell>
                      <TableCell align="center">{row.discharge_date}</TableCell>
                    </TableRow>
                  ))}
              </TableBody>
            </Table>
            <TablePagination
              rowsPerPageOptions={[10, 25, 50]}
              component="div"
              count={tableData.length}
              rowsPerPage={rowsPerPage}
              page={page}
              onPageChange={handleChangePage}
              onRowsPerPageChange={handleChangeRowsPerPage}
            />
          </TableContainer>
        </div>
        </div>
        <Button
          variant="contained"
          onClick={() => {
            const csvRows = [];
            const headers = Object.keys(tableData[0] || {});
            csvRows.push(headers.join(','));
            tableData.forEach(row => {
              const values = headers.map(header => `"${row[header]}"`);
              csvRows.push(values.join(','));
            });
            const csvString = csvRows.join('\n');
            const blob = new Blob([csvString], { type: 'text/csv' });
            const url = window.URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = 'discharge_trends.csv';
            a.click();
          }}
          className="export-csv-button"
        >
          Export CSV
        </Button>
      </div>

  );
}

export default DischargeTrends;