import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import type { GiftProject } from '../types/database';
import { format, isAfter } from 'date-fns';
import LoadingScreen from '../components/LoadingScreen';
import UpcomingProjects from '../components/UpcomingProjects';

export default function Dashboard() {
  const { user } = useAuth();
  const [projects, setProjects] = useState<GiftProject[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function loadProjects() {
      if (!user) return;

      try {
        // First get the project IDs where user is a member
        const { data: memberProjects } = await supabase
          .from('project_members')
          .select('project_id')
          .eq('user_id', user.id)
          .eq('status', 'active');

        const memberProjectIds = memberProjects?.map(p => p.project_id) || [];

        // Then get all projects where user is creator or member
        const { data, error } = await supabase
          .from('gift_projects')
          .select('*')
          .or(`created_by.eq.${user.id},id.in.(${memberProjectIds.join(',')})`);

        if (error) throw error;
        setProjects(data as GiftProject[] || []);
      } catch (error) {
        console.error('Error loading projects:', error);
      } finally {
        setLoading(false);
      }
    }

    loadProjects();
  }, [user]);

  const getStatusBadge = (project: GiftProject) => {
    if (project.status === 'completed') {
      return {
        text: 'Completed',
        className: 'bg-gray-100 text-gray-800'
      };
    }
    if (project.voting_closed) {
      return {
        text: 'Voting Closed',
        className: 'bg-yellow-100 text-yellow-800'
      };
    }
    return {
      text: 'Active',
      className: 'bg-green-100 text-green-800'
    };
  };

  // Filter projects to show
  const filteredProjects = projects.filter(project => {
    // For recurring projects:
    // Only show if it's a parent project or if its parent is completed
    if (project.is_recurring && project.parent_project_id) {
      const parentProject = projects.find(p => p.id === project.parent_project_id);
      return parentProject?.status === 'completed' && 
             isAfter(new Date(project.project_date), new Date());
    }
    // Show all non-recurring projects
    return true;
  });

  if (loading) {
    return <LoadingScreen message="Loading your gift projects..." />;
  }

  return (
    <div className="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
      <div className="px-4 py-6 sm:px-0">
        <div className="flex justify-between items-center mb-6">
          <h1 className="text-2xl font-semibold text-gray-900">Your Gift Projects</h1>
          <Link
            to="/projects/new"
            className="bg-indigo-600 text-white px-4 py-2 rounded-md text-sm font-medium hover:bg-indigo-500"
          >
            New Project
          </Link>
        </div>

        <div className="lg:grid lg:grid-cols-3 lg:gap-8">
          <div className="lg:col-span-2">
            {filteredProjects.length === 0 ? (
              <div className="text-center py-12 bg-white rounded-lg shadow">
                <h3 className="mt-2 text-sm font-semibold text-gray-900">No gift projects</h3>
                <p className="mt-1 text-sm text-gray-500">Get started by creating a new gift project.</p>
                <div className="mt-6">
                  <Link
                    to="/projects/new"
                    className="inline-flex items-center rounded-md bg-indigo-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500"
                  >
                    Create new project
                  </Link>
                </div>
              </div>
            ) : (
              <div className="grid gap-6 md:grid-cols-2">
                {filteredProjects.map((project) => {
                  const status = getStatusBadge(project);
                  return (
                    <Link
                      key={project.id}
                      to={`/projects/${project.id}`}
                      className="block p-6 bg-white rounded-lg border border-gray-200 hover:shadow-md transition-shadow"
                    >
                      <h5 className="mb-2 text-xl font-bold tracking-tight text-gray-900">
                        Gift for {project.recipient_name}
                      </h5>
                      <p className="text-sm text-gray-600">
                        Date: {format(new Date(project.project_date), 'MMM d, yyyy')}
                      </p>
                      {project.interests && project.interests.length > 0 && (
                        <div className="mt-2">
                          <p className="text-sm text-gray-500">Interests:</p>
                          <div className="flex flex-wrap gap-2 mt-1">
                            {project.interests.map((interest, index) => (
                              <span
                                key={index}
                                className="px-2 py-1 text-xs font-medium bg-gray-100 rounded-full text-gray-600"
                              >
                                {interest}
                              </span>
                            ))}
                          </div>
                        </div>
                      )}
                      <div className="mt-4">
                        <span
                          className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${status.className}`}
                        >
                          {status.text}
                        </span>
                      </div>
                    </Link>
                  );
                })}
              </div>
            )}
          </div>

          <div className="mt-8 lg:mt-0">
            <UpcomingProjects projects={projects} />
          </div>
        </div>
      </div>
    </div>
  );
}