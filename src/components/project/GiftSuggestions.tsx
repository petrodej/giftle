import type { GiftSuggestion, Vote, Profile } from '../../types/database';
import VotingControls from './VotingControls';
import AIGiftSuggestions from '../AIGiftSuggestions';

interface Props {
  suggestions: GiftSuggestion[];
  votes: Vote[];
  members: Profile[];
  votingClosed: boolean;
  userId?: string;
  showAISuggestions: boolean;
  onVote: (suggestionId: string, medal: 'gold' | 'silver' | 'bronze') => void;
  onAddSuggestion: () => void;
  project: {
    id: string;
    interests: string[];
  };
}

export default function GiftSuggestions({
  suggestions,
  votes,
  members,
  votingClosed,
  userId,
  showAISuggestions,
  onVote,
  onAddSuggestion,
  project,
}: Props) {
  const calculateVoteScore = (suggestionId: string): number => {
    const suggestionVotes = votes.filter(v => v.suggestion_id === suggestionId);
    return suggestionVotes.reduce((total, vote) => {
      switch (vote.medal) {
        case 'gold': return total + 3;
        case 'silver': return total + 2;
        case 'bronze': return total + 1;
        default: return total;
      }
    }, 0);
  };

  return (
    <div className="p-6">
      <div className="flex justify-between items-center mb-6">
        <h2 className="text-xl font-semibold text-gray-900">Gift Suggestions</h2>
        {!votingClosed && (
          <button
            onClick={onAddSuggestion}
            className="inline-flex items-center px-4 py-2 text-sm font-medium rounded-lg text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
          >
            Add Suggestion
          </button>
        )}
      </div>

      {showAISuggestions && project.interests.length > 0 && (
        <div className="mb-8">
          <AIGiftSuggestions 
            project={project} 
            onSuggestionAdded={onAddSuggestion} 
          />
        </div>
      )}

      <div className="space-y-4">
        {suggestions.map((suggestion) => (
          <div 
            key={suggestion.id} 
            className="bg-white border border-gray-200 rounded-xl shadow-sm hover:shadow-md transition-shadow overflow-hidden"
          >
            <div className="p-6">
              <div className="flex justify-between items-start">
                <div className="flex-1 pr-8">
                  <div className="flex justify-between items-start mb-3">
                    <div>
                      <h3 className="text-lg font-semibold text-gray-900">
                        {suggestion.title}
                      </h3>
                      {suggestion.is_ai_generated && (
                        <span className="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-indigo-50 text-indigo-700 mt-1">
                          AI Generated
                        </span>
                      )}
                    </div>
                    <div className="flex items-center">
                      <span className="px-3 py-1 bg-indigo-50 text-indigo-700 rounded-full text-sm font-medium">
                        {calculateVoteScore(suggestion.id)} points
                      </span>
                    </div>
                  </div>
                  {suggestion.description && (
                    <p className="text-gray-600 mb-3">{suggestion.description}</p>
                  )}
                  <div className="flex items-center space-x-4">
                    {suggestion.price && (
                      <span className="inline-flex items-center text-sm font-medium text-gray-700">
                        <span className="text-gray-400 mr-1">$</span>
                        {suggestion.price}
                      </span>
                    )}
                    {suggestion.url && (
                      <a
                        href={suggestion.url}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="text-sm font-medium text-indigo-600 hover:text-indigo-500"
                      >
                        View Item →
                      </a>
                    )}
                  </div>
                </div>
                {!votingClosed && (
                  <VotingControls
                    suggestionId={suggestion.id}
                    votes={votes}
                    members={members}
                    userId={userId}
                    onVote={onVote}
                  />
                )}
              </div>
            </div>
          </div>
        ))}
        {suggestions.length === 0 && (
          <div className="text-center py-12 bg-gray-50 rounded-xl border border-gray-200">
            <h3 className="text-sm font-medium text-gray-900">No suggestions yet</h3>
            <p className="mt-1 text-sm text-gray-500">
              Be the first to suggest a gift!
            </p>
          </div>
        )}
      </div>
    </div>
  );
}