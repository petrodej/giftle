import { supabase } from './supabase';
import { GiftProject, Vote } from '../types/database';
import { addYears, isBefore } from 'date-fns';

export async function createRecurringProject(originalProject: GiftProject): Promise<void> {
  // Check if the original project is completed
  if (originalProject.status !== 'completed') {
    throw new Error('Cannot create recurring project until current project is completed');
  }

  const nextDate = addYears(new Date(originalProject.project_date), 1);
  
  // Generate a new invite code
  const { data: { invite_code }, error: codeError } = await supabase.rpc('generate_unique_code');
  if (codeError) throw codeError;

  const { error } = await supabase
    .from('gift_projects')
    .insert({
      ...originalProject,
      id: undefined, // Let the database generate a new ID
      created_at: undefined, // Let the database set the timestamp
      parent_project_id: originalProject.id,
      project_date: nextDate.toISOString(),
      status: 'active',
      selected_gift_id: null,
      purchaser_id: null,
      is_recurring: true,
      invite_code: invite_code, // Use the newly generated code
      voting_closed: false,
      completed_at: null
    });

  if (error) throw error;
}

export async function assignRandomPurchaser(projectId: string): Promise<void> {
  // First get all active members with non-null user_ids
  const { data: members, error: membersError } = await supabase
    .from('project_members')
    .select('user_id')
    .eq('project_id', projectId)
    .eq('status', 'active')
    .not('user_id', 'is', null);

  if (membersError) throw membersError;
  if (!members || members.length === 0) throw new Error('No active members found');

  const randomIndex = Math.floor(Math.random() * members.length);
  const selectedPurchaser = members[randomIndex].user_id;

  const { error: updateError } = await supabase
    .from('gift_projects')
    .update({ purchaser_id: selectedPurchaser })
    .eq('id', projectId);

  if (updateError) throw updateError;
}

export async function selectWinningGift(projectId: string): Promise<void> {
  // Get all suggestions and their votes
  const { data: suggestions, error: suggestionsError } = await supabase
    .from('gift_suggestions')
    .select(`
      id,
      votes (
        medal
      )
    `)
    .eq('project_id', projectId);

  if (suggestionsError) throw suggestionsError;
  if (!suggestions || suggestions.length === 0) return;

  // Calculate scores for each suggestion
  const scores = suggestions.map(suggestion => {
    const votes = suggestion.votes || [];
    const score = votes.reduce((total, vote) => {
      switch (vote.medal) {
        case 'gold': return total + 3;
        case 'silver': return total + 2;
        case 'bronze': return total + 1;
        default: return total;
      }
    }, 0);
    return { id: suggestion.id, score };
  });

  // Find the suggestion with the highest score
  const winner = scores.reduce((highest, current) => 
    current.score > highest.score ? current : highest
  );

  // Update the project with the winning suggestion
  const { error: updateError } = await supabase
    .from('gift_projects')
    .update({ selected_gift_id: winner.id })
    .eq('id', projectId);

  if (updateError) throw updateError;
}

export async function checkAndCreateYearlyProjects(): Promise<void> {
  // Only get completed recurring projects that don't have a next occurrence
  const { data: projects, error } = await supabase
    .from('gift_projects')
    .select('*')
    .eq('is_recurring', true)
    .eq('status', 'completed')
    .is('next_occurrence_date', null);

  if (error) throw error;

  for (const project of projects) {
    const nextDate = addYears(new Date(project.project_date), 1);
    if (isBefore(new Date(), nextDate)) {
      await createRecurringProject(project);
    }
  }
}