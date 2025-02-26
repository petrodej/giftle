import React, { useState, useEffect } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import toast from 'react-hot-toast';
import LoadingScreen from '../components/LoadingScreen';

const DEFAULT_PER_PERSON_BUDGET = 20;

interface PendingProject {
  recipientName: string;
  projectDate: string;
  emails: string[];
}

export default function NewProject() {
  const { user } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const [recipientName, setRecipientName] = useState('');
  const [birthDate, setBirthDate] = useState('');
  const [projectDate, setProjectDate] = useState('');
  const [interests, setInterests] = useState('');
  const [budgetType, setBudgetType] = useState<'per_person' | 'total'>('per_person');
  const [perPersonBudget, setPerPersonBudget] = useState(DEFAULT_PER_PERSON_BUDGET);
  const [minBudget, setMinBudget] = useState(50);
  const [maxBudget, setMaxBudget] = useState(200);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    // Check for pending project data
    const pendingProject = location.state?.pendingProject as PendingProject;
    if (pendingProject) {
      setRecipientName(pendingProject.recipientName);
      setProjectDate(pendingProject.projectDate);
    }
  }, [location.state]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!user) return;

    if (budgetType === 'total' && minBudget > maxBudget) {
      toast.error('Minimum budget cannot be greater than maximum budget');
      return;
    }

    setLoading(true);
    try {
      const { data: project, error: projectError } = await supabase
        .from('gift_projects')
        .insert({
          created_by: user.id,
          recipient_name: recipientName,
          birth_date: birthDate || null,
          project_date: projectDate,
          interests: interests.split(',').map(i => i.trim()).filter(i => i),
          min_budget: budgetType === 'per_person' ? perPersonBudget : minBudget,
          max_budget: budgetType === 'per_person' ? perPersonBudget : maxBudget,
          budget_type: budgetType,
          voting_closed: false,
        })
        .select()
        .single();

      if (projectError) throw projectError;

      // Add creator as admin
      const { error: memberError } = await supabase
        .from('project_members')
        .insert({
          project_id: project.id,
          user_id: user.id,
          email: user.email,
          role: 'admin',
          status: 'active'
        });

      if (memberError) throw memberError;

      // Add pending members from the stored project data
      const pendingProject = location.state?.pendingProject as PendingProject;
      if (pendingProject?.emails?.length > 0) {
        const { error: inviteError } = await supabase
          .from('project_members')
          .insert(
            pendingProject.emails.map(email => ({
              project_id: project.id,
              email,
              role: 'member',
              status: 'pending'
            }))
          );

        if (inviteError) throw inviteError;
      }

      toast.success('Project created successfully!');
      navigate(`/projects/${project.id}`);
    } catch (error) {
      toast.error('Failed to create project');
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return <LoadingScreen message="Creating your project..." />;
  }

  return (
    <div className="max-w-2xl mx-auto py-8 px-4 sm:px-6 lg:px-8">
      <div className="md:flex md:items-center md:justify-between mb-8">
        <div className="min-w-0 flex-1">
          <h2 className="text-2xl font-bold leading-7 text-gray-900 sm:truncate sm:text-3xl sm:tracking-tight">
            Create New Gift Project
          </h2>
        </div>
      </div>

      <form onSubmit={handleSubmit} className="bg-white p-8 rounded-lg shadow space-y-6">
        <div className="form-group">
          <label htmlFor="recipientName" className="form-label">
            Recipient's Name
          </label>
          <input
            type="text"
            id="recipientName"
            required
            value={recipientName}
            onChange={(e) => setRecipientName(e.target.value)}
            className="form-input"
            placeholder="Enter recipient's name"
          />
        </div>

        <div className="form-group">
          <label htmlFor="birthDate" className="form-label">
            Birth Date (optional)
          </label>
          <input
            type="date"
            id="birthDate"
            value={birthDate}
            onChange={(e) => setBirthDate(e.target.value)}
            className="form-input"
          />
          <p className="form-hint">
            Used for yearly reminders and age-appropriate suggestions
          </p>
        </div>

        <div className="form-group">
          <label htmlFor="projectDate" className="form-label">
            Gift Date
          </label>
          <input
            type="date"
            id="projectDate"
            required
            value={projectDate}
            onChange={(e) => setProjectDate(e.target.value)}
            className="form-input"
          />
          <p className="form-hint">
            When do you plan to give the gift?
          </p>
        </div>

        <div className="form-group">
          <label htmlFor="interests" className="form-label">
            Interests
          </label>
          <input
            type="text"
            id="interests"
            value={interests}
            onChange={(e) => setInterests(e.target.value)}
            placeholder="e.g., reading, cooking, gaming"
            className="form-input"
          />
          <p className="form-hint">
            Separate multiple interests with commas
          </p>
        </div>

        <div className="space-y-4">
          <label className="form-label">Budget Type</label>
          <div className="flex space-x-6">
            <label className="inline-flex items-center">
              <input
                type="radio"
                value="per_person"
                checked={budgetType === 'per_person'}
                onChange={(e) => setBudgetType(e.target.value as 'per_person' | 'total')}
                className="form-radio h-4 w-4 text-indigo-600 border-gray-300 focus:ring-indigo-500"
              />
              <span className="ml-2 text-sm text-gray-700">Per Person</span>
            </label>
            <label className="inline-flex items-center">
              <input
                type="radio"
                value="total"
                checked={budgetType === 'total'}
                onChange={(e) => setBudgetType(e.target.value as 'per_person' | 'total')}
                className="form-radio h-4 w-4 text-indigo-600 border-gray-300 focus:ring-indigo-500"
              />
              <span className="ml-2 text-sm text-gray-700">Total Budget</span>
            </label>
          </div>
        </div>

        {budgetType === 'per_person' ? (
          <div className="form-group">
            <label htmlFor="perPersonBudget" className="form-label">
              Budget Per Person
            </label>
            <div className="relative">
              <div className="pointer-events-none absolute inset-y-0 left-0 flex items-center pl-3">
                <span className="text-gray-500 sm:text-sm">$</span>
              </div>
              <input
                type="number"
                id="perPersonBudget"
                value={perPersonBudget}
                onChange={(e) => setPerPersonBudget(Math.max(0, Number(e.target.value)))}
                min="0"
                step="1"
                className="form-input pl-7"
                placeholder={DEFAULT_PER_PERSON_BUDGET.toString()}
              />
            </div>
            <p className="form-hint">
              Each person will contribute this amount
            </p>
          </div>
        ) : (
          <div className="form-group">
            <label className="form-label">
              Total Budget Range
            </label>
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label htmlFor="minBudget" className="sr-only">Minimum Budget</label>
                <div className="relative">
                  <div className="pointer-events-none absolute inset-y-0 left-0 flex items-center pl-3">
                    <span className="text-gray-500 sm:text-sm">$</span>
                  </div>
                  <input
                    type="number"
                    id="minBudget"
                    value={minBudget}
                    onChange={(e) => setMinBudget(Math.max(0, Number(e.target.value)))}
                    min="0"
                    step="1"
                    className="form-input pl-7"
                    placeholder="Min"
                  />
                </div>
              </div>
              <div>
                <label htmlFor="maxBudget" className="sr-only">Maximum Budget</label>
                <div className="relative">
                  <div className="pointer-events-none absolute inset-y-0 left-0 flex items-center pl-3">
                    <span className="text-gray-500 sm:text-sm">$</span>
                  </div>
                  <input
                    type="number"
                    id="maxBudget"
                    value={maxBudget}
                    onChange={(e) => setMaxBudget(Math.max(0, Number(e.target.value)))}
                    min="0"
                    step="1"
                    className="form-input pl-7"
                    placeholder="Max"
                  />
                </div>
              </div>
            </div>
            <p className="form-hint">
              The total gift budget range for all contributors
            </p>
          </div>
        )}

        <div className="pt-6">
          <button
            type="submit"
            disabled={loading}
            className="btn-primary w-full"
          >
            {loading ? 'Creating...' : 'Create Project'}
          </button>
        </div>
      </form>
    </div>
  );
}