import React, { useState, useEffect } from 'react';
import { useNavigate, useLocation, Link } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import toast from 'react-hot-toast';

export default function Register() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const { signUp } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();

  // Get redirect URL and email from query parameters
  const searchParams = new URLSearchParams(location.search);
  const redirectTo = searchParams.get('redirect') || '/login';
  const emailParam = searchParams.get('email');

  // Get message from location state
  const locationState = location.state as { message?: string; email?: string } | null;

  useEffect(() => {
    // Set email from query parameter or location state
    if (emailParam) {
      setEmail(emailParam);
    } else if (locationState?.email) {
      setEmail(locationState.email);
    }

    // Set message from location state
    if (locationState?.message) {
      setMessage(locationState.message);
    }
  }, [emailParam, locationState]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setLoading(true);

    try {
      await signUp(email, password);
      toast.success('Registration successful! Please check your email.');
      navigate('/login', {
        state: {
          message: 'Please check your email to confirm your account, then sign in.',
          email: email
        }
      });
    } catch (error: any) {
      console.error('Registration error:', error);
      if (error?.message?.includes('already registered')) {
        setError('This email is already registered. Please sign in instead.');
      } else {
        setError('Failed to create account. Please try again.');
      }
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="flex min-h-full flex-1 flex-col justify-center px-6 py-12 lg:px-8">
      <div className="sm:mx-auto sm:w-full sm:max-w-sm">
        <h2 className="mt-10 text-center text-2xl font-bold leading-9 tracking-tight text-gray-900">
          Create your account
        </h2>
      </div>

      <div className="mt-10 sm:mx-auto sm:w-full sm:max-w-sm">
        <form className="space-y-6" onSubmit={handleSubmit}>
          {message && (
            <div className="rounded-md bg-blue-50 p-4">
              <div className="flex">
                <div className="flex-shrink-0">
                  <svg className="h-5 w-5 text-blue-400" viewBox="0 0 20 20" fill="currentColor">
                    <path fillRule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clipRule="evenodd" />
                  </svg>
                </div>
                <div className="ml-3">
                  <p className="text-sm text-blue-700">{message}</p>
                </div>
              </div>
            </div>
          )}

          {error && (
            <div className="rounded-md bg-red-50 p-4">
              <div className="flex">
                <div className="flex-shrink-0">
                  <svg className="h-5 w-5 text-red-400" viewBox="0 0 20 20" fill="currentColor">
                    <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clipRule="evenodd" />
                  </svg>
                </div>
                <div className="ml-3">
                  <p className="text-sm text-red-700">{error}</p>
                  {error?.includes('already registered') && (
                    <p className="mt-2 text-sm text-red-700">
                      <Link
                        to={`/login?redirect=${encodeURIComponent(redirectTo)}&email=${encodeURIComponent(email)}`}
                        className="font-medium text-red-700 underline hover:text-red-600"
                      >
                        Click here to sign in instead
                      </Link>
                    </p>
                  )}
                </div>
              </div>
            </div>
          )}

          <div>
            <label htmlFor="email" className="form-label">
              Email address
            </label>
            <input
              id="email"
              name="email"
              type="email"
              autoComplete="email"
              required
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="form-input"
              placeholder="Enter your email"
            />
          </div>

          <div>
            <label htmlFor="password" className="form-label">
              Password
            </label>
            <input
              id="password"
              name="password"
              type="password"
              autoComplete="new-password"
              required
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="form-input"
              placeholder="Choose a password"
            />
            <p className="form-hint">
              Must be at least 8 characters long
            </p>
          </div>

          <div>
            <button 
              type="submit" 
              className="btn-primary w-full"
              disabled={loading}
            >
              {loading ? 'Creating account...' : 'Create account'}
            </button>
          </div>
        </form>

        {redirectTo.includes('/join/') && (
          <p className="mt-6 text-center text-sm text-gray-500">
            Already have an account?{' '}
            <Link
              to={`/login?redirect=${encodeURIComponent(redirectTo)}&email=${encodeURIComponent(email)}`}
              className="font-semibold leading-6 text-indigo-600 hover:text-indigo-500"
            >
              Sign in
            </Link>
          </p>
        )}
      </div>
    </div>
  );
}