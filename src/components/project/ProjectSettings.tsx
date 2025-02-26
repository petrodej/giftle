import { useState } from 'react';
import { format } from 'date-fns';
import { Dialog } from '@headlessui/react';
import { supabase } from '../../lib/supabase';
import toast from 'react-hot-toast';
import type { GiftProject } from '../../types/database';

interface Props {
  project: GiftProject;
  isOpen: boolean;
  onClose: () => void;
  onProjectUpdate: (project: GiftProject) => void;
}

export default function ProjectSettings({ project, isOpen, onClose, onProjectUpdate }: Props) {
  const [saving, setSaving] = useState(false);
  const [formData, setFormData] = useState({
    recipientName: project.recipient_name,
    birthDate: project.birth_date ? format(new Date(project.birth_date), 'yyyy-MM-dd') : '',
    projectDate: format(new Date(project.project_date), 'yyyy-MM-dd'),
    budgetType: project.budget_type || 'per_person',
    minBudget: project.min_budget?.toString() || '',
    maxBudget: project.max_budget?.toString() || ''
  });

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSaving(true);

    try {
      // Validate budget values
      if (formData.budgetType === 'total' && 
          Number(formData.minBudget) > Number(formData.maxBudget)) {
        throw new Error('Minimum budget cannot be greater than maximum budget');
      }

      const { data: updatedProject, error } = await supabase
        .from('gift_projects')
        .update({
          recipient_name: formData.recipientName,
          birth_date: formData.birthDate || null,
          project_date: formData.projectDate,
          budget_type: formData.budgetType,
          min_budget: formData.minBudget ? Number(formData.minBudget) : null,
          max_budget: formData.maxBudget ? Number(formData.maxBudget) : null
        })
        .eq('id', project.id)
        .select()
        .single();

      if (error) throw error;

      onProjectUpdate(updatedProject as GiftProject);
      toast.success('Project settings updated successfully');
      onClose();
    } catch (error) {
      console.error('Error updating project:', error);
      toast.error('Failed to update project settings');
    } finally {
      setSaving(false);
    }
  };

  return (
    <Dialog open={isOpen} onClose={onClose} className="relative z-50">
      <div className="fixed inset-0 bg-black/30" aria-hidden="true" />
      
      <div className="fixed inset-0 flex items-center justify-center p-4">
        <Dialog.Panel className="mx-auto max-w-lg w-full rounded-lg bg-white shadow-xl">
          <div className="p-6">
            <Dialog.Title className="text-xl font-semibold text-gray-900 mb-6">
              Project Settings
            </Dialog.Title>

            <form onSubmit={handleSubmit} className="space-y-6">
              <div className="form-group">
                <label htmlFor="recipientName" className="form-label">
                  Recipient's Name
                </label>
                <input
                  type="text"
                  id="recipientName"
                  value={formData.recipientName}
                  onChange={(e) => setFormData(prev => ({ ...prev, recipientName: e.target.value }))}
                  className="form-input"
                  required
                />
              </div>

              <div className="form-group">
                <label htmlFor="birthDate" className="form-label">
                  Birth Date (optional)
                </label>
                <input
                  type="date"
                  id="birthDate"
                  value={formData.birthDate}
                  onChange={(e) => setFormData(prev => ({ ...prev, birthDate: e.target.value }))}
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
                  value={formData.projectDate}
                  onChange={(e) => setFormData(prev => ({ ...prev, projectDate: e.target.value }))}
                  className="form-input"
                  required
                />
                <p className="form-hint">
                  When do you plan to give the gift?
                </p>
              </div>

              <div className="space-y-4">
                <label className="form-label">Budget Type</label>
                <div className="flex space-x-6">
                  <label className="inline-flex items-center">
                    <input
                      type="radio"
                      value="per_person"
                      checked={formData.budgetType === 'per_person'}
                      onChange={(e) => setFormData(prev => ({ ...prev, budgetType: e.target.value as 'per_person' | 'total' }))}
                      className="form-radio h-4 w-4 text-indigo-600 border-gray-300 focus:ring-indigo-500"
                    />
                    <span className="ml-2 text-sm text-gray-700">Per Person</span>
                  </label>
                  <label className="inline-flex items-center">
                    <input
                      type="radio"
                      value="total"
                      checked={formData.budgetType === 'total'}
                      onChange={(e) => setFormData(prev => ({ ...prev, budgetType: e.target.value as 'per_person' | 'total' }))}
                      className="form-radio h-4 w-4 text-indigo-600 border-gray-300 focus:ring-indigo-500"
                    />
                    <span className="ml-2 text-sm text-gray-700">Total Budget</span>
                  </label>
                </div>
              </div>

              {formData.budgetType === 'per_person' ? (
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
                      value={formData.minBudget}
                      onChange={(e) => setFormData(prev => ({ 
                        ...prev, 
                        minBudget: e.target.value,
                        maxBudget: e.target.value 
                      }))}
                      min="0"
                      step="1"
                      className="form-input pl-7"
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
                          value={formData.minBudget}
                          onChange={(e) => setFormData(prev => ({ ...prev, minBudget: e.target.value }))}
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
                          value={formData.maxBudget}
                          onChange={(e) => setFormData(prev => ({ ...prev, maxBudget: e.target.value }))}
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

              <div className="flex justify-end space-x-4 pt-6">
                <button
                  type="button"
                  onClick={onClose}
                  className="btn-secondary"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={saving}
                  className="btn-primary"
                >
                  {saving ? 'Saving...' : 'Save Changes'}
                </button>
              </div>
            </form>
          </div>
        </Dialog.Panel>
      </div>
    </Dialog>
  );
}