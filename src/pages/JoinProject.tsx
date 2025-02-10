import { useState, useEffect } from 'react';
import { useParams, useNavigate, Link, useSearchParams } from 'react-router-dom';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import toast from 'react-hot-toast';
import LoadingScreen from '../components/LoadingScreen';
import type { Database } from '../types/supabase';

type Project = Database['public']['Tables']['gift_projects']['Row'];

export default function JoinProject() {
  const { inviteCode } = useParams<{ inviteCode: string }>();
  const [searchParams] = useSearchParams();
  const email = searchParams.get('email');
  const { user } = useAuth();
  const navigate = useNavigate();
  
  const [loading, setLoading] = useState(true);
  const [joining, setJoining] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [project, setProject] = useState<Project | null>(null);
  const [checkingEmail, setCheckingEmail] = useState(false);

  useEffect(() => {
    if (!inviteCode) {
      setError('Invalid invite link - no invite code provided');
      setLoading(false);
      return;
    }

    loadProjectDetails();
  }, [inviteCode, user]);

  async function loadProjectDetails() {
    if (!inviteCode) return;

    try {
      console.log('Looking up project with invite code:', inviteCode);

      // First get the project details
      const { data: projectData, error: projectError } = await supabase
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
        .eq('invite_code', inviteCode)
        .limit(1)
        .maybeSingle();

      if (projectError) {
        console.error('Error loading project:', projectError);
        setError('Unable to load project details. Please try again.');
        return;
      }

      console.log('Project lookup result:', projectData);

      if (!projectData) {
        // Try to get all projects to see if the code exists
        const { data: allProjects } = await supabase
          .from('gift_projects')
          .select('invite_code')
          .limit(10);

        console.log('Available invite codes:', allProjects?.map(p => p.invite_code));
        
        setError('This invite link is invalid. Please ask for a new invite link.');
        return;
      }

      // Check project status
      if (projectData.status === 'completed' || projectData.completed_at) {
        setError('This project has been completed and is no longer accepting new members.');
        return;
      }

      setProject(projectData);

      // If user is logged in, check if they're already a member
      if (user) {
        console.log('Checking membership for user:', user.id);

        const { data: memberData, error: memberError } = await supabase
          .from('project_members')
          .select('status, role')
          .eq('project_id', projectData.id)
          .eq('user_id', user.id)
          .maybeSingle();

        if (memberError) {
          console.error('Error checking membership:', memberError);
          setError('Unable to verify membership status. Please try again.');
          return;
        }

        console.log('Membership check result:', memberData);

        if (memberData?.status === 'active') {
          toast.success('You are already a member of this project');
          navigate(`/projects/${projectData.id}`);
          return;
        }

        // If user is logged in but not a member, join automatically
        if (user.email) {
          await handleJoin(user.email);
          return;
        }
      }

      // Check if email from URL is already a member
      if (email) {
        console.log('Checking membership for email:', email);

        const { data: existingMember, error: memberError } = await supabase
          .from('project_members')
          .select('status')
          .eq('project_id', projectData.id)
          .eq('email', email)
          .maybeSingle();

        if (memberError) {
          console.error('Error checking email membership:', memberError);
        } else if (existingMember?.status === 'active') {
          setError('This email is already a member of the project. Please sign in to access it.');
          return;
        }

        console.log('Email membership check result:', existingMember);
      }

      setError(null);
    } catch (error) {
      console.error('Error loading project:', error);
      setError('Unable to load project details. Please try again.');
    } finally {
      setLoading(false);
    }
  }

  async function handleJoin(userEmail: string) {
    if (!project) return;

    setJoining(true);
    try {
      console.log('Attempting to join project:', project.id, 'with email:', userEmail);

      // Check for existing membership
      const { data: existingMember, error: checkError } = await supabase
        .from('project_members')
        .select('*')
        .eq('project_id', project.id)
        .eq('email', userEmail)
        .maybeSingle();

      if (checkError) throw checkError;

      console.log('Existing member check result:', existingMember);

      if (existingMember) {
        // Update existing member
        const { error: updateError } = await supabase
          .from('project_members')
          .update({ 
            status: 'active',
            user_id: user?.id 
          })
          .eq('project_id', project.id)
          .eq('email', userEmail);

        if (updateError) throw updateError;

        console.log('Updated existing member');
      } else {
        // Create new member
        const { error: insertError } = await supabase
          .from('project_members')
          .insert({
            project_id: project.id,
            user_id: user?.id,
            email: userEmail,
            role: 'member',
            status: 'active'
          });

        if (insertError) {
          if (insertError.message.includes('duplicate')) {
            throw new Error('You are already a member of this project');
          }
          throw insertError;
        }

        console.log('Created new member');
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
      console.log('Checking if user exists with email:', submittedEmail);

      // Check if user exists with this email
      const { data: userData, error: userError } = await supabase
        .from('profiles')
        .select('id')
        .eq('email', submittedEmail)
        .maybeSingle();

      if (userError) {
        console.error('Error checking email:', userError);
        toast.error('An error occurred. Please try again.');
        return;
      }

      console.log('User lookup result:', userData);

      if (userData) {
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
      console.error('Error checking email:', error);
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