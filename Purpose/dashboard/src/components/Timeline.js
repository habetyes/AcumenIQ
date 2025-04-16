import React, { useState, useEffect } from 'react';
import { supabase } from '../supabaseClient';
import { useNavigate, Link } from 'react-router-dom';
import { TextField, Button, Card, CardContent } from '@mui/material';
import KPIExport from './KPIExport';
import '../styles.css';
import _ from 'lodash';

function Timeline() {
  const [startDate, setStartDate] = useState('');
  const [endDate, setEndDate] = useState('');
  const [data, setData] = useState([]);
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
    if (startDate && endDate) {
      const { data: kpiData, error } = await supabase
        .from('vw_daily_census')
        .select('*')
        .gte('census_date', startDate)
        .lte('census_date', endDate);

      if (error) {
        console.error('Error fetching KPI data:', error);
      } else {
        setData(kpiData);
      }
    }
  };

  useEffect(() => {
    fetchData();
  }, [startDate, endDate]);

  const calculateAggregates = (data) => {
    const groupedByDate = _.groupBy(data, 'census_date');
    const dailyTotals = Object.values(groupedByDate).map((dayData) => {
      return dayData.reduce((acc, item) => acc + (item.census || 0), 0);
    });

    const totalCensus = dailyTotals.reduce((acc, total) => acc + total, 0);
    const averageCensus = dailyTotals.length > 0 ? totalCensus / dailyTotals.length : 0;

    const totals = data.reduce(
      (acc, item) => {
        acc.admissions += item.admissions || 0;
        acc.transfer_in += item.transfer_in || 0;
        acc.transfer_out += item.transfer_out || 0;
        acc.discharges += item.discharges || 0;
        return acc;
      },
      { admissions: 0, transfer_in: 0, transfer_out: 0, discharges: 0 }
    );

    return {
      ...totals,
      census: averageCensus,
    };
  };

  const calculateProgramAggregates = (data) => {
    const groupedByProgram = _.groupBy(data, 'program_category');
    return Object.entries(groupedByProgram).map(([program, programData]) => {
      const totalCensus = programData.reduce((acc, item) => acc + (item.census || 0), 0);
      const averageCensus = programData.length > 0 ? totalCensus / programData.length : 0;

      const totals = programData.reduce(
        (acc, item) => {
          acc.admissions += item.admissions || 0;
          acc.transfer_in += item.transfer_in || 0;
          acc.transfer_out += item.transfer_out || 0;
          acc.discharges += item.discharges || 0;
          return acc;
        },
        { admissions: 0, transfer_in: 0, transfer_out: 0, discharges: 0 }
      );

      return {
        program,
        averageCensus,
        ...totals,
      };
    });
  };

  const aggregates = calculateAggregates(data);
  const programAggregates = calculateProgramAggregates(data);

  return (
    <div className="dashboard-container">
      <h2>Purpose: Timeline</h2>
      <div className="dashboard-controls">
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
        <Button variant="contained" component={Link} to="/dashboard">
          Back to Dashboard
        </Button>
      </div>
      <div className="dashboard-totals">
        <div className="total-item">Avg Census: {aggregates.census.toFixed(1)}</div>
        <div className="total-item">Admissions: {aggregates.admissions}</div>
        <div className="total-item">Transfers In: {aggregates.transfer_in}</div>
        <div className="total-item">Transfers Out: {aggregates.transfer_out}</div>
        <div className="total-item">Discharges: {aggregates.discharges}</div>
      </div>
      <div className="dashboard-cards">
        {programAggregates.map((programData, index) => (
          <Card key={index}>
            <CardContent>
              <h3>{programData.program}</h3>
              <p>Avg Census: {programData.averageCensus.toFixed(1)}</p>
              <p>Admissions: {programData.admissions}</p>
              <p>Transfers In: {programData.transfer_in}</p>
              <p>Transfers Out: {programData.transfer_out}</p>
              <p>Discharges: {programData.discharges}</p>
            </CardContent>
          </Card>
        ))}
      </div>
      {data.length > 0 && <KPIExport data={data} />}
    </div>
  );
}

export default Timeline;