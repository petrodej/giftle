import { useState, useEffect } from 'react';
import { supabase } from '../../lib/supabase';
import type { GiftProject } from '../../types/database';

interface Props {
  project: GiftProject;
}

export default function BudgetInfo({ project }: Props) {
  const [activeMemberCount, setActiveMemberCount] = useState(0);

  useEffect(() => {
    loadActiveMemberCount();

    // Subscribe to member changes
    const channel = supabase
      .channel('member_changes')
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'project_members',
          filter: `project_id=eq.${project.id}`
        },
        () => {
          loadActiveMemberCount();
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [project.id]);

  const loadActiveMemberCount = async () => {
    try {
      const { count, error } = await supabase
        .from('project_members')
        .select('*', { count: 'exact', head: true })
        .eq('project_id', project.id)
        .eq('status', 'active');

      if (error) throw error;
      setActiveMemberCount(count || 1); // Default to 1 if count is null
    } catch (error) {
      console.error('Error loading member count:', error);
      setActiveMemberCount(1); // Default to 1 on error
    }
  };

  const formatBudget = (amount: number | null) => {
    if (amount === null) return '—';
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
      minimumFractionDigits: 2,
      maximumFractionDigits: 2
    }).format(amount);
  };

  const getBudgetDisplay = () => {
    if (!project.budget_type || !project.min_budget) return null;

    if (project.budget_type === 'per_person') {
      const perPersonAmount = project.min_budget;
      const totalAmount = perPersonAmount * activeMemberCount;
      return `${formatBudget(totalAmount)} (${formatBudget(perPersonAmount)} Per Person × ${activeMemberCount} members)`;
    } else {
      // For fixed budget, just show the amount
      if (project.min_budget === project.max_budget) {
        return formatBudget(project.min_budget);
      }
      // For range, show the range
      return `${formatBudget(project.min_budget)} - ${formatBudget(project.max_budget)}`;
    }
  };

  if (!project.budget_type || (!project.min_budget && !project.max_budget)) {
    return null;
  }

  const budgetDisplay = getBudgetDisplay();
  if (!budgetDisplay) return null;

  return (
    <div className="bg-white border-b">
      <div className="px-6 py-3 flex items-center">
        <div className="flex items-center space-x-2">
          <span className="text-sm text-gray-500">Budget:</span>
          <span className="text-sm font-medium text-gray-900">
            {budgetDisplay}
          </span>
        </div>
      </div>
    </div>
  );
}