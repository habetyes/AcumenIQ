import React, { useEffect, useState } from 'react';
import { supabase } from '../supabaseClient';
import { useNavigate } from 'react-router-dom';

function Login() {
  const [email, setEmail] = useState('');
  const navigate = useNavigate();

  //Check if user is already logged in
  useEffect(() => {
    const checkUser = async () => {
      const { data: { session } } = await supabase.auth.getSession();
      if (session) {
        navigate('/dashboard'); // Redirect to home if logged in
      }
    };

    checkUser();
  } , [navigate]);

  const handleLogin = async (e) => {
    e.preventDefault();
    // Use the environment variable for the redirect URL; default to localhost if not set
    const redirectUrl = process.env.REACT_APP_REDIRECT_URL || 'localhost:3000';
    const { error } = await supabase.auth.signInWithOtp({
      email,
      options: {
        redirectTo: redirectUrl,
      },
    });
    
    if (error) {
      alert(error.message);
    } else {
      alert('Check your email for the login link!');
    }
  };

  return (
    <form onSubmit={handleLogin}>
      <input
        type="email"
        value={email}
        onChange={(e) => setEmail(e.target.value)}
        placeholder="Your email"
        required
      />
      <button type="submit">Log In</button>
    </form>
  );
}

export default Login;
