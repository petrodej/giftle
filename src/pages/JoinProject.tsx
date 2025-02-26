import { useState, useEffect } from 'react';
import { useParams, useNavigate, Link, useSearchParams } from 'react-router-dom';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import toast from 'react-hot-toast';
import LoadingScreen from '../components/LoadingScreen';
import type { GiftProject } from '../types/database';

interface ProjectData {
  id: string;
  recipient_name: string;
  created_by: string;
  project_date: string;
  status: string;
  invite_code: string;
  completed_at: string | null;
}

export default function JoinProject() {
  const { inviteCode } = useParams<{ inviteCode: string }>();
  const [searchParams] = useSearchParams();
  const email = searchParams.get('email');
  const { user } = useAuth();
  const navigate = useNavigate();
  
  const [loading, setLoading] = useState(true);
  const [joining, setJoining] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [project, setProject] = useState<GiftProject | null>(null);
  const [checkingEmail, setCheckingEmail] = useState(false);

  useEffect(() => {
    if (!inviteCode) {
      setError('Invalid invite link - no invite code provided');
      setLoading(false);
      return;
    }

    loadProjectDetails();
  }, [inviteCode]);

  // Separate effect for handling join after project is loaded
  useEffect(() => {
    if (user?.email && project) {
      handleJoin();
    }
  }, [user, project]);

  async function loadProjectDetails() {
    if (!inviteCode) return;

    try {
      // Get project details using invite code
      const { data: projects, error: projectError } = await supabase
        .from('gift_projects')
        .select(`
          id,
          recipient_name,
          created_by,
          project_date,
          status,
          invite_code,
          completed_at
        `)
        .eq('invite_code', inviteCode);

      if (projectError) throw projectError;

      if (!projects || projects.length === 0) {
        setError('This invite link is invalid. Please ask for a new invite link.');
        return;
      }

      const projectData = projects[0] as ProjectData;

      // Check project status
      if (projectData.status === 'completed' || projectData.completed_at) {
        setError('This project has been completed and is no longer accepting new members.');
        return;
      }

      setProject(projectData as GiftProject);
      setError(null);
    } catch (error) {
      console.error('Error loading project details:', error);
      setError('Unable to load project details. Please try again.');
    } finally {
      setLoading(false);
    }
  }

  async function handleJoin() {
    if (!project || !user?.email) return;

    setJoining(true);
    try {
      // Call the join_project function
      const { error: joinError } = await supabase.rpc('join_project', {
        input_project_id: project.id,
        input_invite_code: inviteCode
      });

      if (joinError) {
        // Handle specific error cases
        if (joinError.message.includes('Invalid project or invite code')) {
          throw new Error('This invite link is no longer valid. Please ask for a new invite link.');
        } else if (joinError.message.includes('User must be authenticated')) {
          throw new Error('Please sign in to join this project.');
        } else {
          throw joinError;
        }
      }

      toast.success('Successfully joined the project!');
      navigate(`/projects/${project.id}`);
    } catch (error) {
      console.error('Error joining project:', error);
      const message = error instanceof Error ? error.message : 'Failed to join project';
      toast.error(message);
      setError(message);
    } finally {
      setJoining(false);
    }
  }

  async function handleEmailSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const formData = new FormData(e.currentTarget);
    const submittedEmail = formData.get('email') as string;
    
    if (!submittedEmail || !project) {
      toast.error('Please enter a valid email address');
      return;
    }

    setCheckingEmail(true);
    try {
      // Check if user exists by looking up their profile
      const { data: profile } = await supabase
        .from('profiles')
        .select('id')
        .eq('email', submittedEmail)
        .maybeSingle();

      if (profile) {
        // User exists, redirect to login
        navigate(`/login?redirect=/join/${inviteCode}&email=${encodeURIComponent(submittedEmail)}`, {
          state: { 
            message: 'Please sign in to join the project',
            email: submittedEmail
          }
        });
      } else {
        // User doesn't exist, redirect to register
        navigate(`/register?redirect=/join/${inviteCode}&email=${encodeURIComponent(submittedEmail)}`, {
          state: { 
            message: 'Create an account to join the project',
            email: submittedEmail
          }
        });
      }
    } catch (error) {
      toast.error('An error occurred. Please try again.');
    } finally {
      setCheckingEmail(false);
    }
  }

  if (loading) {
    return <LoadingScreen fullScreen message="Loading project details..." />;
  }

  if (error) {
    return (
      <div className="min-h-screen bg-gray-50 flex flex-col justify-center py-12 sm:px-6 lg:px-8">
        <div className="sm:mx-auto sm:w-full sm:max-w-md">
          <div className="bg-white py-8 px-4 shadow sm:rounded-lg sm:px-10">
            <div className="text-center">
              <div className="inline-flex items-center justify-center w-12 h-12 rounded-full bg-red-100 mb-4">
                <svg className="w-6 h-6 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </div>
              <h2 className="text-lg font-medium text-gray-900 mb-2">Unable to Join Project</h2>
              <p className="text-sm text-gray-500 mb-6">{error}</p>
              <div className="space-y-4">
                <Link
                  to="/"
                  className="inline-flex justify-center py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
                >
                  Return to Home
                </Link>
                {error.includes('sign in') && (
                  <Link
                    to={`/login?redirect=/join/${inviteCode}${email ? `&email=${encodeURIComponent(email)}` : ''}`}
                    className="block text-sm text-indigo-600 hover:text-indigo-500"
                  >
                    Sign in to your account
                  </Link>
                )}
              </div>
            </div>
          </div>
        </div>
      </div>
    );
  }

  if (!project) {
    return null;
  }

  if (joining) {
    return <LoadingScreen fullScreen message="Joining project..." />;
  }

  return (
    <div className="min-h-screen bg-gray-50 flex flex-col justify-center py-12 sm:px-6 lg:px-8">
      <div className="sm:mx-auto sm:w-full sm:max-w-md">
        <h2 className="mt-6 text-center text-3xl font-bold tracking-tight text-gray-900">
          Join Gift Project
        </h2>
      </div>

      <div className="mt-8 sm:mx-auto sm:w-full sm:max-w-md">
        <div className="bg-white py-8 px-4 shadow sm:rounded-lg sm:px-10">
          <div className="text-center">
            <p className="text-sm text-gray-600 mb-4">
              You've been invited to join a gift project for
            </p>
            <p className="text-xl font-semibold text-gray-900 mb-6">
              {project.recipient_name}
            </p>

            <div className="space-y-4">
              <p className="text-sm text-gray-600">
                Please enter your email to join this project
              </p>
              <form onSubmit={handleEmailSubmit} className="mt-4">
                <div className="form-group">
                  <label htmlFor="email" className="form-label">
                    Email address
                  </label>
                  <input
                    id="email"
                    name="email"
                    type="email"
                    required
                    defaultValue={email || ''}
                    className="form-input"
                    placeholder="Enter your email"
                  />
                </div>

                <button
                  type="submit"
                  disabled={checkingEmail}
                  className="mt-4 w-full flex justify-center py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 disabled:opacity-50"
                >
                  {checkingEmail ? 'Checking...' : 'Continue'}
                </button>
              </form>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}