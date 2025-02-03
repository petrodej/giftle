import { useState } from 'react';
import { Dialog } from '@headlessui/react';
import { supabase } from '../lib/supabase';
import toast from 'react-hot-toast';
import LoadingScreen from './LoadingScreen';
import type { GiftSuggestion } from '../types/database';

interface Props {
  projectId: string;
  isOpen: boolean;
  onClose: () => void;
  onSuggestionAdded: (suggestion: GiftSuggestion) => void;
}

export default function AddSuggestionModal({ projectId, isOpen, onClose, onSuggestionAdded }: Props) {
  const [loading, setLoading] = useState(false);
  const [suggestion, setSuggestion] = useState({
    title: '',
    description: '',
    price: '',
    url: '',
  });

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);

    try {
      const { data, error } = await supabase
        .from('gift_suggestions')
        .insert({
          project_id: projectId,
          suggested_by: (await supabase.auth.getUser()).data.user?.id,
          title: suggestion.title,
          description: suggestion.description,
          price: suggestion.price ? parseFloat(suggestion.price) : null,
          url: suggestion.url || null,
        })
        .select()
        .single();

      if (error) throw error;

      onSuggestionAdded(data as GiftSuggestion);
      toast.success('Suggestion added successfully!');
      setSuggestion({ title: '', description: '', price: '', url: '' });
      onClose();
    } catch (error) {
      toast.error('Failed to add suggestion');
    } finally {
      setLoading(false);
    }
  };

  return (
    <Dialog open={isOpen} onClose={onClose} className="relative z-50">
      <div className="fixed inset-0 bg-black/30" aria-hidden="true" />
      
      <div className="fixed inset-0 flex items-center justify-center p-4">
        <Dialog.Panel className="mx-auto max-w-md w-full rounded-lg bg-white p-8 shadow-xl">
          {loading ? (
            <LoadingScreen message="Adding suggestion..." />
          ) : (
            <>
              <Dialog.Title className="text-xl font-semibold text-gray-900 mb-6">
                Add Gift Suggestion
              </Dialog.Title>

              <form onSubmit={handleSubmit} className="space-y-6">
                <div className="form-group">
                  <label htmlFor="title" className="form-label">Title</label>
                  <input
                    id="title"
                    type="text"
                    placeholder="Enter gift title"
                    value={suggestion.title}
                    onChange={(e) => setSuggestion({ ...suggestion, title: e.target.value })}
                    required
                    className="form-input"
                  />
                </div>

                <div className="form-group">
                  <label htmlFor="description" className="form-label">Description</label>
                  <textarea
                    id="description"
                    placeholder="Enter gift description"
                    value={suggestion.description}
                    onChange={(e) => setSuggestion({ ...suggestion, description: e.target.value })}
                    rows={3}
                    className="form-textarea"
                  />
                </div>

                <div className="grid grid-cols-2 gap-6">
                  <div className="form-group">
                    <label htmlFor="price" className="form-label">Price</label>
                    <div className="relative">
                      <div className="pointer-events-none absolute inset-y-0 left-0 flex items-center pl-3">
                        <span className="text-gray-500 sm:text-sm">$</span>
                      </div>
                      <input
                        id="price"
                        type="number"
                        placeholder="0.00"
                        value={suggestion.price}
                        onChange={(e) => setSuggestion({ ...suggestion, price: e.target.value })}
                        className="form-input pl-7"
                        step="0.01"
                        min="0"
                      />
                    </div>
                  </div>

                  <div className="form-group">
                    <label htmlFor="url" className="form-label">URL (optional)</label>
                    <input
                      id="url"
                      type="url"
                      placeholder="https://"
                      value={suggestion.url}
                      onChange={(e) => setSuggestion({ ...suggestion, url: e.target.value })}
                      className="form-input"
                    />
                  </div>
                </div>

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
                    className="btn-primary"
                  >
                    Add Suggestion
                  </button>
                </div>
              </form>
            </>
          )}
        </Dialog.Panel>
      </div>
    </Dialog>
  );
}