import { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import toast from 'react-hot-toast';
import LoadingScreen from '../components/LoadingScreen';
import type { Database } from '../types/supabase';

type Project = Database['public']['Tables']['gift_projects']['Row'];

export default function JoinProject() {
  const { inviteCode } = useParams<{ inviteCode: string }>();
  const { user } = useAuth();
  const navigate = useNavigate();
  const [loading, setLoading] = useState(true);
  const [projectName, setProjectName] = useState('');

  useEffect(() => {
    loadProjectDetails();
  }, [inviteCode]);

  async function loadProjectDetails() {
    if (!inviteCode) return;

    try {
      const { data: project, error } = await supabase
        .from('gift_projects')
        .select('recipient_name')
        .eq('invite_code', inviteCode)
        .single();

      if (error) throw error;
      setProjectName((project as Project).recipient_name);
    } catch (error) {
      toast.error('Invalid or expired invite link');
      navigate('/');
    } finally {
      setLoading(false);
    }
  }

  async function handleJoin() {
    if (!user || !inviteCode) return;

    setLoading(true);
    try {
      // Get project ID from invite code
      const { data: project, error: projectError } = await supabase
        .from('gift_projects')
        .select('id')
        .eq('invite_code', inviteCode)
        .single();

      if (projectError) throw projectError;

      // Update pending member to active
      const { error: memberError } = await supabase
        .from('project_members')
        .update({ 
          status: 'active',
          user_id: user.id 
        })
        .eq('project_id', project.id)
        .eq('email', user.email);

      if (memberError) {
        // If no pending invitation found, create new member
        const { error: insertError } = await supabase
          .from('project_members')
          .insert({
            project_id: project.id,
            user_id: user.id,
            role: 'member',
            status: 'active'
          });

        if (insertError) throw insertError;
      }

      toast.success('Successfully joined the project!');
      navigate(`/projects/${project.id}`);
    } catch (error) {
      toast.error('Failed to join project');
    } finally {
      setLoading(false);
    }
  }

  if (loading) {
    return <LoadingScreen fullScreen message="Loading project details..." />;
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
              {projectName}
            </p>

            {user ? (
              <button
                onClick={handleJoin}
                disabled={loading}
                className="w-full flex justify-center py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 disabled:opacity-50"
              >
                {loading ? 'Joining...' : 'Join Project'}
              </button>
            ) : (
              <div className="space-y-4">
                <p className="text-sm text-gray-600">
                  Please sign in or create an account to join this project
                </p>
                <div className="flex flex-col space-y-3">
                  <button
                    onClick={() => navigate('/login')}
                    className="w-full flex justify-center py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700"
                  >
                    Sign In
                  </button>
                  <button
                    onClick={() => navigate('/register')}
                    className="w-full flex justify-center py-2 px-4 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50"
                  >
                    Create Account
                  </button>
                </div>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}