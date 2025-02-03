import type { Vote, Profile } from '../../types/database';

interface Props {
  suggestionId: string;
  votes: Vote[];
  members: Profile[];
  userId?: string;
  onVote: (suggestionId: string, medal: 'gold' | 'silver' | 'bronze') => void;
}

interface VoterInfo {
  name: string;
  email: string;
}

export default function VotingControls({
  suggestionId,
  votes,
  members,
  userId,
  onVote,
}: Props) {
  const getUserVote = () => {
    if (!userId) return null;
    return votes.find(v => v.suggestion_id === suggestionId && v.user_id === userId)?.medal || null;
  };

  const getMedalCounts = () => {
    const suggestionVotes = votes.filter(v => v.suggestion_id === suggestionId);
    return {
      gold: suggestionVotes.filter(v => v.medal === 'gold').length,
      silver: suggestionVotes.filter(v => v.medal === 'silver').length,
      bronze: suggestionVotes.filter(v => v.medal === 'bronze').length
    };
  };

  const getVoterInfo = (medal: 'gold' | 'silver' | 'bronze'): VoterInfo[] => {
    return votes
      .filter(v => v.suggestion_id === suggestionId && v.medal === medal)
      .map(v => {
        const member = members.find(m => m.id === v.user_id);
        // Only return email as name if no full name is available
        return {
          name: member?.full_name || member?.email || 'Anonymous',
          email: member?.email || ''
        };
      })
      .sort((a, b) => a.name.localeCompare(b.name)); // Sort alphabetically
  };

  const userVote = getUserVote();
  const medalCounts = getMedalCounts();

  return (
    <div className="flex flex-col items-end space-y-3 min-w-[140px]">
      {['gold', 'silver', 'bronze'].map((medal) => (
        <div key={medal} className="flex items-center space-x-3 w-full justify-end">
          <button
            onClick={() => onVote(suggestionId, medal as 'gold' | 'silver' | 'bronze')}
            className={`flex items-center justify-center w-10 h-10 rounded-lg transition-colors ${
              userVote === medal
                ? medal === 'gold'
                  ? 'bg-yellow-100 text-yellow-700'
                  : medal === 'silver'
                  ? 'bg-gray-200 text-gray-700'
                  : 'bg-orange-100 text-orange-700'
                : `bg-gray-50 hover:bg-${medal === 'gold' ? 'yellow' : medal === 'silver' ? 'gray' : 'orange'}-50 text-gray-700 hover:text-${medal === 'gold' ? 'yellow' : medal === 'silver' ? 'gray' : 'orange'}-700`
            }`}
          >
            <span className="text-xl">{medal === 'gold' ? '🥇' : medal === 'silver' ? '🥈' : '🥉'}</span>
          </button>

          <div className="relative group">
            <div className="px-2 py-1 text-sm font-medium text-gray-600 bg-gray-50 rounded-lg cursor-help min-w-[32px] text-center">
              {medalCounts[medal as keyof typeof medalCounts]}
            </div>
            {/* Tooltip */}
            <div className="absolute z-50 invisible group-hover:visible opacity-0 group-hover:opacity-100 transition-all duration-200 -translate-x-full left-0 top-1/2 -translate-y-1/2 mr-2">
              <div className="bg-white border rounded-lg shadow-lg p-3 text-sm whitespace-nowrap min-w-[150px]">
                <div className="font-medium text-gray-900 mb-2">
                  {medal === 'gold' ? 'Gold' : medal === 'silver' ? 'Silver' : 'Bronze'} Votes
                </div>
                <div className="space-y-1">
                  {getVoterInfo(medal as 'gold' | 'silver' | 'bronze').map((voter, i) => (
                    <div key={i} className="text-gray-600">
                      {voter.name}
                    </div>
                  ))}
                  {getVoterInfo(medal as 'gold' | 'silver' | 'bronze').length === 0 && (
                    <div className="text-gray-500 italic">No votes yet</div>
                  )}
                </div>
              </div>
            </div>
          </div>
        </div>
      ))}
    </div>
  );
}