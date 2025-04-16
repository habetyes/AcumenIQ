import React from 'react';
import { Link } from 'react-router-dom';
import '../styles.css';

function Header() {
  return (
    <header className="header">
      <div>Purpose</div>
      <nav>
        {/* <Link to="/login">Login</Link> */}
        <Link to="/census">Census</Link>
        <Link to="/censustrends">Census Trends</Link>
        <Link to="/dischargetrends">Discharges</Link>
      </nav>
    </header>
  );
}

export default Header;