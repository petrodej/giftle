import { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import type { GiftProject } from '../types/database';
import { format, isAfter } from 'date-fns';
import LoadingScreen from '../components/LoadingScreen';
import UpcomingProjects from '../components/UpcomingProjects';
import toast from 'react-hot-toast';
import { TrashIcon } from '@heroicons/react/24/outline';

interface ProjectWithRole extends GiftProject {
  role: 'admin' | 'member';
}

interface MemberProject {
  project_id: string;
  role: 'admin' | 'member';
  status: string;
  gift_projects: GiftProject;
}

export default function Dashboard() {
  const { user } = useAuth();
  const [projects, setProjects] = useState<ProjectWithRole[]>([]);
  const [loading, setLoading] = useState(true);
  const [deleting, setDeleting] = useState<string | null>(null);

  useEffect(() => {
    if (user?.email) {
      loadProjects();
    }
  }, [user]);

  async function loadProjects() {
    if (!user?.email) return;

    try {
      // Get all projects where user is a member (by email or user_id)
      const { data: memberProjects, error: memberError } = await supabase
        .from('project_members')
        .select(`
          project_id,
          role,
          status,
          gift_projects (
            id,
            created_by,
            recipient_name,
            birth_date,
            interests,
            created_at,
            project_date,
            status,
            selected_gift_id,
            purchaser_id,
            invite_code,
            parent_project_id,
            is_recurring,
            next_occurrence_date,
            min_budget,
            max_budget,
            budget_type,
            voting_closed,
            completed_at
          )
        `)
        .eq('status', 'active')
        .or(`email.eq.${user.email},user_id.eq.${user.id}`);

      if (memberError) throw memberError;

      // Get all projects where user is creator
      const { data: createdProjects, error: creatorError } = await supabase
        .from('gift_projects')
        .select('*')
        .eq('created_by', user.id);

      if (creatorError) throw creatorError;

      // Combine and deduplicate projects
      const memberProjectsFormatted = (memberProjects || [])
        .filter((mp: any) => mp.gift_projects) // Filter out any null projects
        .map((mp: any) => ({
          ...mp.gift_projects,
          role: mp.role as 'admin' | 'member'
        }));

      const createdProjectsFormatted = (createdProjects || []).map(project => ({
        ...project,
        role: 'admin' as const
      }));

      // Combine projects, preferring created projects over member projects
      const projectMap = new Map<string, ProjectWithRole>();
      
      // Add member projects first
      memberProjectsFormatted.forEach(project => {
        if (project.id) {
          projectMap.set(project.id, project);
        }
      });

      // Override with created projects (as admin)
      createdProjectsFormatted.forEach(project => {
        if (project.id) {
          projectMap.set(project.id, project);
        }
      });

      setProjects(Array.from(projectMap.values()));
    } catch (error) {
      console.error('Error loading projects:', error);
      toast.error('Failed to load projects');
    } finally {
      setLoading(false);
    }
  }

  const handleDeleteProject = async (projectId: string) => {
    if (!confirm('Are you sure you want to delete this project? This action cannot be undone.')) {
      return;
    }

    setDeleting(projectId);
    try {
      const { error } = await supabase
        .from('gift_projects')
        .delete()
        .eq('id', projectId);

      if (error) throw error;

      setProjects(prev => prev.filter(p => p.id !== projectId));
      toast.success('Project deleted successfully');
    } catch (error) {
      console.error('Error deleting project:', error);
      toast.error('Failed to delete project');
    } finally {
      setDeleting(null);
    }
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
              <div className="space-y-4">
                {filteredProjects.map((project) => {
                  const isCreator = project.created_by === user?.id;
                  const isDeleting = deleting === project.id;

                  return (
                    <div
                      key={project.id}
                      className="relative bg-white rounded-lg border border-gray-200 hover:shadow-md transition-shadow overflow-hidden group"
                    >
                      <Link
                        to={`/projects/${project.id}`}
                        className="block p-6"
                      >
                        <div className="flex justify-between items-start">
                          <div className="flex-1 pr-16">
                            <div className="flex justify-between items-start mb-2">
                              <h5 className="text-xl font-bold tracking-tight text-gray-900">
                                Gift for {project.recipient_name}
                              </h5>
                              <span
                                className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
                                  project.role === 'admin' 
                                    ? 'bg-indigo-100 text-indigo-800'
                                    : 'bg-blue-100 text-blue-800'
                                }`}
                              >
                                {project.role === 'admin' ? 'Admin' : 'Member'}
                              </span>
                            </div>
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
                                className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
                                  project.status === 'completed'
                                    ? 'bg-gray-100 text-gray-800'
                                    : project.voting_closed
                                    ? 'bg-yellow-100 text-yellow-800'
                                    : 'bg-green-100 text-green-800'
                                }`}
                              >
                                {project.status === 'completed'
                                  ? 'Completed'
                                  : project.voting_closed
                                  ? 'Voting Closed'
                                  : 'Active'}
                              </span>
                            </div>
                          </div>
                        </div>
                      </Link>

                      {isCreator && (
                        <div className="absolute top-2 right-2 opacity-0 group-hover:opacity-100 transition-opacity">
                          <button
                            onClick={(e) => {
                              e.preventDefault();
                              handleDeleteProject(project.id);
                            }}
                            disabled={isDeleting}
                            className={`
                              p-2 text-gray-400 hover:text-red-600 rounded-full
                              hover:bg-red-50 transition-colors
                              ${isDeleting ? 'opacity-50 cursor-not-allowed' : ''}
                            `}
                            title="Delete project"
                          >
                            <TrashIcon className="h-5 w-5" />
                          </button>
                        </div>
                      )}
                    </div>
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