#!/bin/bash
set -e

echo "Setting up project structure..."

# Create directories for shared code
mkdir -p lambda
mkdir -p supabase
mkdir -p dashboard/public
mkdir -p dashboard/src
mkdir -p dashboard/src/components

###############################
# Create AWS Lambda Script
###############################
echo "Creating lambda/lambda_update.py..."
cat > lambda/lambda_update.py <<'EOF'
import os
import json
import logging
import requests
import psycopg2
from psycopg2.extras import execute_values

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def fetch_kipu_data():
    """
    Fetch data from the Kipu API.
    Expected response: JSON with keys "admissions", "transfers", "discharges"
    """
    kipu_api_url = os.environ.get("KIPU_API_URL")
    api_key = os.environ.get("KIPU_API_KEY")
    headers = {"Authorization": f"Bearer {api_key}"}
    response = requests.get(kipu_api_url, headers=headers)
    if response.status_code != 200:
        logger.error("Error fetching data from Kipu API")
        raise Exception("Kipu API request failed")
    data = response.json()
    return data

def transform_data(raw_data):
    """
    Minimal transformation to match the Supabase schema.
    """
    admissions = raw_data.get("admissions", [])
    transfers = raw_data.get("transfers", [])
    discharges = raw_data.get("discharges", [])
    return {
        "admissions": admissions,
        "transfers": transfers,
        "discharges": discharges
    }

def load_data_to_supabase(data):
    """
    Connects to Supabase Postgres and inserts/updates records.
    Then triggers a stored procedure to refresh materialized views.
    """
    conn = psycopg2.connect(
        host=os.environ.get("SUPABASE_HOST"),
        dbname=os.environ.get("SUPABASE_DB"),
        user=os.environ.get("SUPABASE_USER"),
        password=os.environ.get("SUPABASE_PASSWORD"),
        port=os.environ.get("SUPABASE_PORT", 5432)
    )
    conn.autocommit = True
    cursor = conn.cursor()
    
    for table in ["admissions", "transfers", "discharges"]:
        records = data.get(table, [])
        if records:
            # Assumes each record is a dict whose keys match the table columns.
            columns = records[0].keys()
            sql = f"""
                INSERT INTO {table} ({', '.join(columns)}) 
                VALUES %s 
                ON CONFLICT (id) DO UPDATE SET 
                {", ".join([f"{col}=EXCLUDED.{col}" for col in columns if col != 'id'])}
            """
            values = [tuple(record[col] for col in columns) for record in records]
            try:
                execute_values(cursor, sql, values)
                logger.info(f"Inserted/Updated {len(records)} records into {table}")
            except Exception as e:
                logger.error(f"Error inserting records into {table}: {str(e)}")
                raise e

    # Trigger the stored procedure to refresh materialized views
    try:
        cursor.execute("CALL refresh_materialized_views();")
        logger.info("Materialized views refreshed")
    except Exception as e:
        logger.error("Error refreshing materialized views: " + str(e))
        raise e
    finally:
        cursor.close()
        conn.close()

def lambda_handler(event, context):
    try:
        raw_data = fetch_kipu_data()
        transformed_data = transform_data(raw_data)
        load_data_to_supabase(transformed_data)
        return {
            'statusCode': 200,
            'body': json.dumps('Data load successful')
        }
    except Exception as e:
        logger.error("ETL process failed: " + str(e))
        return {
            'statusCode': 500,
            'body': json.dumps('ETL process failed')
        }
EOF

###############################
# Create Supabase Schema
###############################
echo "Setting up Supabase schema..."
if [ -f "schema.sql" ]; then
  echo "Found schema.sql in the current directory. Using it as the Supabase schema."
  cp schema.sql supabase/schema.sql
else
  echo "No schema.sql found. Using default Supabase schema..."
  cat > supabase/schema.sql <<'EOF'
-- Default Supabase Schema
-- Stored Procedure to refresh materialized views
CREATE OR REPLACE PROCEDURE refresh_materialized_views()
LANGUAGE plpgsql
AS $$
BEGIN
  REFRESH MATERIALIZED VIEW mv_kpi_daily;
  REFRESH MATERIALIZED VIEW mv_discharge_trends;
END;
$$;

-- Materialized View for Daily KPIs
CREATE MATERIALIZED VIEW mv_kpi_daily AS
SELECT
  organization_id,
  program,
  DATE(created_at) as date,
  COUNT(DISTINCT CASE WHEN source = 'admissions' THEN id END) as admissions,
  COUNT(DISTINCT CASE WHEN source = 'transfers' THEN id END) as transfers,
  COUNT(DISTINCT CASE WHEN source = 'discharges' THEN id END) as discharges,
  COUNT(DISTINCT patient_id) as census
FROM (
  SELECT id, organization_id, program, created_at, patient_id, 'admissions' as source FROM admissions
  UNION ALL
  SELECT id, organization_id, program, created_at, patient_id, 'transfers' as source FROM transfers
  UNION ALL
  SELECT id, organization_id, program, created_at, patient_id, 'discharges' as source FROM discharges
) sub
GROUP BY organization_id, program, DATE(created_at);

-- Materialized View for Discharge Trends
CREATE MATERIALIZED VIEW mv_discharge_trends AS
SELECT
  organization_id,
  program,
  DATE(created_at) as date,
  discharge_type,
  COUNT(*) as count
FROM discharges
GROUP BY organization_id, program, DATE(created_at), discharge_type;
EOF
fi

###############################
# Create React Frontend
###############################
echo "Creating dashboard/package.json..."
cat > dashboard/package.json <<'EOF'
{
  "name": "dashboard",
  "version": "1.0.0",
  "private": true,
  "dependencies": {
    "react": "^18.0.0",
    "react-dom": "^18.0.0",
    "react-router-dom": "^6.0.0",
    "@supabase/supabase-js": "^2.0.0",
    "@mui/material": "^5.0.0",
    "chart.js": "^3.0.0",
    "react-chartjs-2": "^3.0.0",
    "axios": "^0.27.2"
  },
  "scripts": {
    "start": "react-scripts start",
    "build": "react-scripts build"
  }
}
EOF

echo "Creating dashboard/public/index.html..."
cat > dashboard/public/index.html <<'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>AcumenIQ Dashboard</title>
</head>
<body>
  <div id="root"></div>
</body>
</html>
EOF

echo "Creating dashboard/src/index.js..."
cat > dashboard/src/index.js <<'EOF'
import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
EOF

echo "Creating dashboard/src/App.js..."
cat > dashboard/src/App.js <<'EOF'
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
EOF

echo "Creating dashboard/src/supabaseClient.js..."
cat > dashboard/src/supabaseClient.js <<'EOF'
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseAnonKey = process.env.SUPABASE_KEY;

export const supabase = createClient(supabaseUrl, supabaseAnonKey);
EOF

echo "Creating dashboard/src/components/Login.js..."
cat > dashboard/src/components/Login.js <<'EOF'
import React, { useState } from 'react';
import { supabase } from '../supabaseClient';
import { useNavigate } from 'react-router-dom';

function Login() {
  const [email, setEmail] = useState('');
  const navigate = useNavigate();

  const handleLogin = async (e) => {
    e.preventDefault();
    const { error } = await supabase.auth.signInWithOtp({ email });
    if (error) {
      alert(error.message);
    } else {
      alert('Check your email for the login link!');
    }
  };

  return (
    <div style={{ padding: '2rem' }}>
      <h2>Login to AcumenIQ</h2>
      <form onSubmit={handleLogin}>
        <input
          type="email"
          placeholder="Your email"
          value={email}
          onChange={e => setEmail(e.target.value)}
          required
        />
        <button type="submit">Send Magic Link</button>
      </form>
    </div>
  );
}

export default Login;
EOF

echo "Creating dashboard/src/components/Dashboard.js..."
cat > dashboard/src/components/Dashboard.js <<'EOF'
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
      .from('mv_kpi_daily')
      .select('*')
      .eq('date', selectedDate);
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
EOF

echo "Creating dashboard/src/components/DischargeTrends.js..."
cat > dashboard/src/components/DischargeTrends.js <<'EOF'
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
EOF

echo "Creating dashboard/src/components/KPIExport.js..."
cat > dashboard/src/components/KPIExport.js <<'EOF'
import React from 'react';

function KPIExport({ data }) {
  const exportToCSV = () => {
    const csvRows = [];
    const headers = Object.keys(data[0]);
    csvRows.push(headers.join(','));
    data.forEach(row => {
      const values = headers.map(header => `"${row[header]}"`);
      csvRows.push(values.join(','));
    });
    const csvString = csvRows.join('\n');
    const blob = new Blob([csvString], { type: 'text/csv' });
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'kpi_data.csv';
    a.click();
  };

  return (
    <button onClick={exportToCSV}>Export CSV</button>
  );
}

export default KPIExport;
EOF

###############################
# Docker Setup for React Frontend
###############################
echo "Creating dashboard/Dockerfile..."
cat > dashboard/Dockerfile <<'EOF'
# Use an official Node runtime as a parent image
FROM node:16-alpine

# Set working directory
WORKDIR /app

# Copy package files and install dependencies
COPY package.json ./
RUN npm install

# Copy the rest of the app source code
COPY . .

# Expose port 3000 for the React app
EXPOSE 3000

# Start the app (hot reloading enabled)
CMD ["npm", "start"]
EOF

echo "Creating docker-compose.yml at project root..."
cat > docker-compose.yml <<'EOF'
version: '3.8'
services:
  dashboard:
    build:
      context: ./dashboard
      dockerfile: Dockerfile
    ports:
      - "3000:3000"
    volumes:
      - ./dashboard/src:/app/src
      - ./dashboard/public:/app/public
    environment:
      - SUPABASE_URL=${SUPABASE_URL}
      - SUPABASE_KEY=${SUPABASE_KEY}
EOF

echo "Creating sample .env file for frontend environment variables..."
cat > .env <<'EOF'
SUPABASE_URL=https://your-production-supabase-url.supabase.co
SUPABASE_KEY=your-production-supabase-anon-key
EOF

echo "Project setup complete!"
echo "To start the React frontend locally via Docker, run: docker-compose up --build"
