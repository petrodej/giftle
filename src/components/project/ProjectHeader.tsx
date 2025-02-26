import { format } from 'date-fns';
import { useState } from 'react';
import { PlusIcon, XMarkIcon, PencilIcon } from '@heroicons/react/24/outline';
import toast from 'react-hot-toast';
import type { GiftProject } from '../../types/database';
import ProjectSettings from './ProjectSettings';

interface Props {
  project: GiftProject;
  isAdmin?: boolean;
  onUpdateInterests: (interests: string[]) => Promise<void>;
  onProjectUpdate: (project: GiftProject) => void;
}

export default function ProjectHeader({ project, isAdmin, onUpdateInterests, onProjectUpdate }: Props) {
  const [newInterest, setNewInterest] = useState('');
  const [isAdding, setIsAdding] = useState(false);
  const [showSettings, setShowSettings] = useState(false);

  const handleAddInterest = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newInterest.trim()) return;

    try {
      const updatedInterests = [...(project.interests || []), newInterest.trim()];
      await onUpdateInterests(updatedInterests);
      setNewInterest('');
      setIsAdding(false);
      toast.success('Interest added successfully');
    } catch (error) {
      // Error handling is done in parent component
    }
  };

  const handleRemoveInterest = async (interestToRemove: string) => {
    try {
      const updatedInterests = project.interests.filter(
        interest => interest !== interestToRemove
      );
      await onUpdateInterests(updatedInterests);
      toast.success('Interest removed successfully');
    } catch (error) {
      // Error handling is done in parent component
    }
  };

  return (
    <>
      <div className="bg-gradient-to-r from-indigo-600 to-indigo-500 p-6 text-white">
        <div className="flex justify-between items-start">
          <div>
            <div className="flex items-center gap-3">
              <h1 className="text-2xl font-bold mb-2">
                Gift for {project.recipient_name}
              </h1>
              {isAdmin && (
                <button
                  onClick={() => setShowSettings(true)}
                  className="p-1 text-white/80 hover:text-white hover:bg-white/10 rounded-full transition-colors"
                  title="Edit project settings"
                >
                  <PencilIcon className="h-5 w-5" />
                </button>
              )}
            </div>
            <p className="text-indigo-100">
              {format(new Date(project.project_date), 'MMMM d, yyyy')}
            </p>
            <div className="mt-3">
              <div className="flex flex-wrap gap-2">
                {project.interests && project.interests.map((interest, index) => (
                  <span
                    key={`${interest}-${index}`}
                    className="px-3 py-1.5 text-sm font-medium bg-white/20 backdrop-blur-sm rounded-full text-white shadow-sm group relative"
                  >
                    {interest}
                    {(isAdmin || !project.voting_closed) && (
                      <button
                        onClick={() => handleRemoveInterest(interest)}
                        className="absolute -right-1 -top-1 p-0.5 rounded-full bg-red-600 text-white opacity-0 group-hover:opacity-100 transition-opacity"
                      >
                        <XMarkIcon className="h-3 w-3" />
                      </button>
                    )}
                  </span>
                ))}
                {(isAdmin || !project.voting_closed) && (
                  isAdding ? (
                    <form onSubmit={handleAddInterest} className="inline-flex">
                      <input
                        type="text"
                        value={newInterest}
                        onChange={(e) => setNewInterest(e.target.value)}
                        className="px-3 py-1 text-sm bg-white/20 backdrop-blur-sm rounded-full text-white placeholder-white/50 focus:outline-none focus:ring-2 focus:ring-white/50"
                        placeholder="Add interest..."
                        autoFocus
                        onBlur={() => {
                          if (!newInterest.trim()) {
                            setIsAdding(false);
                          }
                        }}
                      />
                    </form>
                  ) : (
                    <button
                      onClick={() => setIsAdding(true)}
                      className="inline-flex items-center px-2 py-1 text-sm font-medium bg-white/20 hover:bg-white/30 backdrop-blur-sm rounded-full text-white transition-colors"
                    >
                      <PlusIcon className="h-4 w-4 mr-1" />
                      Add Interest
                    </button>
                  )
                )}
              </div>
            </div>
          </div>
          <div className="flex flex-col items-end space-y-2">
            <span
              className={`inline-flex items-center px-3 py-1 rounded-full text-xs font-medium ${
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

      <ProjectSettings
        project={project}
        isOpen={showSettings}
        onClose={() => setShowSettings(false)}
        onProjectUpdate={onProjectUpdate}
      />
    </>
  );
}