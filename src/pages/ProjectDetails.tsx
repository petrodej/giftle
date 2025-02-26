import { useState, useEffect } from 'react';
import { useParams } from 'react-router-dom';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import type { GiftProject, GiftSuggestion, Vote, Profile } from '../types/database';
import toast from 'react-hot-toast';
import InviteMembersModal from '../components/InviteMembersModal';
import MembersList from '../components/MembersList';
import LoadingScreen from '../components/LoadingScreen';
import AddSuggestionModal from '../components/AddSuggestionModal';
import ProjectHeader from '../components/project/ProjectHeader';
import AdminActions from '../components/project/AdminActions';
import GiftSuggestions from '../components/project/GiftSuggestions';
import BudgetInfo from '../components/project/BudgetInfo';
import { createRecurringProject } from '../lib/projectManager';

interface MemberQueryResult {
  user_id: string | null;
  role: string;
  status: 'active' | 'pending';
  email: string;
  joined_at: string;
  profiles: {
    id: string;
    email: string;
    full_name: string | null;
    avatar_url: string | null;
    created_at: string;
    updated_at: string;
  } | null;
}

export default function ProjectDetails() {
  const { id } = useParams<{ id: string }>();
  const { user } = useAuth();
  const [project, setProject] = useState<GiftProject | null>(null);
  const [suggestions, setSuggestions] = useState<GiftSuggestion[]>([]);
  const [votes, setVotes] = useState<Vote[]>([]);
  const [loading, setLoading] = useState(true);
  const [isAdmin, setIsAdmin] = useState(false);
  const [showInviteModal, setShowInviteModal] = useState(false);
  const [showAddSuggestionModal, setShowAddSuggestionModal] = useState(false);
  const [isRecurring, setIsRecurring] = useState(false);
  const [hasRandomPurchaser, setHasRandomPurchaser] = useState(false);
  const [showAISuggestions, setShowAISuggestions] = useState(false);
  const [members, setMembers] = useState<Profile[]>([]);

  useEffect(() => {
    if (id) {
      loadProjectData();
    }
  }, [id]);

  useEffect(() => {
    if (project) {
      setIsRecurring(project.is_recurring || false);
      setHasRandomPurchaser(!!project.purchaser_id);
    }
  }, [project]);

  async function loadProjectData() {
    if (!id || !user) return;

    setLoading(true);
    try {
      // Load project details
      const { data: projectData, error: projectError } = await supabase
        .from('gift_projects')
        .select('*')
        .eq('id', id)
        .single();

      if (projectError) throw projectError;
      setProject(projectData as GiftProject);

      // Load member profiles
      const { data: memberData, error: memberError } = await supabase
        .from('project_members')
        .select(`
          user_id,
          role,
          status,
          email,
          joined_at,
          profiles:user_id (
            id,
            email,
            full_name,
            avatar_url,
            created_at,
            updated_at
          )
        `)
        .eq('project_id', id);

      if (memberError) throw memberError;

      // Transform member data
      const profiles: Profile[] = (memberData as unknown as MemberQueryResult[])
        .filter(m => m.profiles) // Only include members with profiles
        .map(m => ({
          id: m.profiles!.id,
          email: m.profiles!.email,
          full_name: m.profiles!.full_name,
          avatar_url: m.profiles!.avatar_url,
          created_at: m.profiles!.created_at,
          updated_at: m.profiles!.updated_at
        }));

      setMembers(profiles);

      // Check if current user is admin
      const currentUserMember = memberData.find(m => m.user_id === user.id);
      setIsAdmin(currentUserMember?.role === 'admin');

      // Load suggestions
      const { data: suggestionsData, error: suggestionsError } = await supabase
        .from('gift_suggestions')
        .select('*')
        .eq('project_id', id);

      if (suggestionsError) throw suggestionsError;
      setSuggestions(suggestionsData as GiftSuggestion[] || []);

      // Load votes if there are suggestions
      if (suggestionsData && suggestionsData.length > 0) {
        const { data: votesData, error: votesError } = await supabase
          .from('votes')
          .select('*')
          .in('suggestion_id', suggestionsData.map(s => s.id));

        if (votesError) throw votesError;
        setVotes(votesData as Vote[] || []);
      }
    } catch (error) {
      console.error('Error loading project data:', error);
      toast.error('Failed to load project data');
    } finally {
      setLoading(false);
    }
  }

  async function handleUpdateInterests(newInterests: string[]) {
    if (!project || !id) return;

    try {
      const { error } = await supabase
        .from('gift_projects')
        .update({ interests: newInterests })
        .eq('id', id);

      if (error) throw error;

      setProject(prev => prev ? { ...prev, interests: newInterests } : null);
    } catch (error) {
      console.error('Error updating interests:', error);
      toast.error('Failed to update interests');
      throw error;
    }
  }

  async function handleToggleRecurring(checked: boolean) {
    if (!project || !isAdmin) return;

    // Optimistically update UI
    setIsRecurring(checked);
    setProject(prev => prev ? { ...prev, is_recurring: checked } : null);

    try {
      const { error } = await supabase
        .from('gift_projects')
        .update({ is_recurring: checked })
        .eq('id', project.id);

      if (error) throw error;
      
      toast.success(checked ? 'Project set to yearly recurring' : 'Project no longer recurring');
    } catch (error) {
      // Revert on error
      setIsRecurring(!checked);
      setProject(prev => prev ? { ...prev, is_recurring: !checked } : null);
      console.error('Error updating recurring status:', error);
      toast.error('Failed to update recurring status');
    }
  }

  async function handleToggleRandomPurchaser(checked: boolean) {
    if (!project || !isAdmin) return;

    // Optimistically update UI
    setHasRandomPurchaser(checked);

    try {
      if (checked) {
        const { data, error } = await supabase.rpc('assign_random_purchaser', {
          input_project_id: project.id
        });

        if (error) throw error;
        
        // Update project with new purchaser
        setProject(prev => prev ? { ...prev, purchaser_id: data.purchaser_id } : null);
        toast.success('Random purchaser assigned');
      } else {
        const { error } = await supabase
          .from('gift_projects')
          .update({ purchaser_id: null })
          .eq('id', project.id);

        if (error) throw error;

        // Update project with removed purchaser
        setProject(prev => prev ? { ...prev, purchaser_id: null } : null);
        toast.success('Purchaser assignment removed');
      }
    } catch (error) {
      // Revert on error
      setHasRandomPurchaser(!checked);
      console.error('Error updating purchaser:', error);
      toast.error('Failed to update purchaser');
    }
  }

  async function handleCloseVoting() {
    if (!project || !isAdmin) return;

    try {
      const { error } = await supabase
        .from('gift_projects')
        .update({ voting_closed: true })
        .eq('id', project.id);

      if (error) throw error;
      
      setProject(prev => prev ? { ...prev, voting_closed: true } : null);
      toast.success('Voting has been closed');
    } catch (error) {
      console.error('Error closing voting:', error);
      toast.error('Failed to close voting');
    }
  }

  async function handleReopenVoting() {
    if (!project || !isAdmin) return;

    try {
      const { error } = await supabase
        .from('gift_projects')
        .update({ voting_closed: false })
        .eq('id', project.id);

      if (error) throw error;
      
      setProject(prev => prev ? { ...prev, voting_closed: false } : null);
      toast.success('Voting has been reopened');
    } catch (error) {
      console.error('Error reopening voting:', error);
      toast.error('Failed to reopen voting');
    }
  }

  async function handleCloseProject() {
    if (!project || !isAdmin) return;

    try {
      const { error } = await supabase
        .from('gift_projects')
        .update({ 
          status: 'completed',
          completed_at: new Date().toISOString()
        })
        .eq('id', project.id);

      if (error) throw error;
      
      setProject(prev => prev ? { 
        ...prev, 
        status: 'completed',
        completed_at: new Date().toISOString()
      } : null);

      if (project.is_recurring) {
        await createRecurringProject(project);
        toast.success('Project completed and next year\'s project created');
      } else {
        toast.success('Project has been completed');
      }
    } catch (error) {
      console.error('Error closing project:', error);
      toast.error('Failed to close project');
    }
  }

  async function handleVote(suggestionId: string, medal: 'gold' | 'silver' | 'bronze') {
    if (!user || !project || project.voting_closed) return;

    try {
      const existingVoteForMedal = votes.find(v => 
        v.user_id === user.id && 
        v.medal === medal
      );

      if (existingVoteForMedal?.suggestion_id === suggestionId) {
        const { error } = await supabase
          .from('votes')
          .delete()
          .match({
            suggestion_id: suggestionId,
            user_id: user.id
          });

        if (error) throw error;

        setVotes(prev => prev.filter(v => 
          !(v.suggestion_id === suggestionId && v.user_id === user.id)
        ));
      } else {
        if (existingVoteForMedal) {
          const { error: deleteError } = await supabase
            .from('votes')
            .delete()
            .match({
              user_id: user.id,
              medal: medal
            });

          if (deleteError) throw deleteError;

          setVotes(prev => prev.filter(v => !(v.user_id === user.id && v.medal === medal)));
        }

        const existingVoteOnSuggestion = votes.find(v => 
          v.suggestion_id === suggestionId && 
          v.user_id === user.id
        );

        if (existingVoteOnSuggestion) {
          const { error: deleteOldError } = await supabase
            .from('votes')
            .delete()
            .match({
              suggestion_id: suggestionId,
              user_id: user.id
            });

          if (deleteOldError) throw deleteOldError;

          setVotes(prev => prev.filter(v => 
            !(v.suggestion_id === suggestionId && v.user_id === user.id)
          ));
        }

        const { error: insertError } = await supabase
          .from('votes')
          .insert({
            suggestion_id: suggestionId,
            user_id: user.id,
            medal: medal
          });

        if (insertError) throw insertError;

        setVotes(prev => [
          ...prev.filter(v => !(v.user_id === user.id && v.medal === medal)),
          {
            suggestion_id: suggestionId,
            user_id: user.id,
            medal,
            created_at: new Date().toISOString()
          }
        ]);
      }
    } catch (error) {
      console.error('Error updating vote:', error);
      toast.error('Failed to update vote');
      loadProjectData();
    }
  }

  if (loading) {
    return <LoadingScreen message="Loading project details..." />;
  }

  if (!project) {
    return (
      <div className="max-w-7xl mx-auto py-12 px-4">
        <div className="text-center">
          <h3 className="text-lg font-medium text-gray-900">Project not found</h3>
          <p className="mt-2 text-sm text-gray-500">
            The project you're looking for doesn't exist or you don't have access to it.
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="max-w-7xl mx-auto py-6 px-4 sm:px-6 lg:px-8">
      <div className="lg:grid lg:grid-cols-3 lg:gap-8">
        <div className="lg:col-span-2">
          <div className="bg-white shadow rounded-lg overflow-hidden">
            <ProjectHeader 
              project={project} 
              isAdmin={isAdmin}
              onUpdateInterests={handleUpdateInterests}
              onProjectUpdate={setProject}
            />

            <BudgetInfo project={project} />

            {isAdmin && project.status !== 'completed' && (
              <AdminActions
                isRecurring={isRecurring}
                hasRandomPurchaser={hasRandomPurchaser}
                votingClosed={project.voting_closed}
                showAISuggestions={showAISuggestions}
                onToggleRecurring={handleToggleRecurring}
                onToggleRandomPurchaser={handleToggleRandomPurchaser}
                onToggleAISuggestions={setShowAISuggestions}
                onCloseVoting={handleCloseVoting}
                onReopenVoting={handleReopenVoting}
                onCloseProject={handleCloseProject}
              />
            )}

            <GiftSuggestions
              suggestions={suggestions}
              votes={votes}
              members={members}
              votingClosed={project.voting_closed}
              userId={user?.id}
              showAISuggestions={showAISuggestions}
              onVote={handleVote}
              onAddSuggestion={() => setShowAddSuggestionModal(true)}
              project={{
                id: project.id,
                interests: project.interests
              }}
            />
          </div>
        </div>

        <div className="mt-8 lg:mt-0">
          <MembersList 
            projectId={project.id}
            isAdmin={isAdmin}
            onInviteClick={() => setShowInviteModal(true)}
          />
        </div>
      </div>

      {project && isAdmin && (
        <InviteMembersModal
          projectId={project.id}
          inviteCode={project.invite_code}
          isOpen={showInviteModal}
          onClose={() => setShowInviteModal(false)}
        />
      )}

      <AddSuggestionModal
        projectId={project.id}
        isOpen={showAddSuggestionModal}
        onClose={() => setShowAddSuggestionModal(false)}
        onSuggestionAdded={(suggestion) => {
          setSuggestions(prev => [...prev, suggestion]);
        }}
      />
    </div>
  );
}