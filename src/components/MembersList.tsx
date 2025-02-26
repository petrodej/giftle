import { useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';
import { Profile } from '../types/database';
import LoadingScreen from './LoadingScreen';
import { useAuth } from '../contexts/AuthContext';
import toast from 'react-hot-toast';
import { PlusIcon, TrashIcon } from '@heroicons/react/24/outline';

interface Member extends Profile {
  role: string;
  status: 'active' | 'pending';
  email: string;
  joined_at: string;
}

interface Props {
  projectId: string;
  onMembersChange?: () => void;
  onInviteClick?: () => void;
  isAdmin?: boolean;
}

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

export default function MembersList({ projectId, onMembersChange, onInviteClick, isAdmin }: Props) {
  const [members, setMembers] = useState<Member[]>([]);
  const [loading, setLoading] = useState(true);
  const { user } = useAuth();

  useEffect(() => {
    const channel = supabase
      .channel('project_members')
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'project_members',
          filter: `project_id.eq.${projectId}`
        },
        () => {
          loadMembers();
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [projectId]);

  useEffect(() => {
    loadMembers();
  }, [projectId]);

  async function loadMembers() {
    try {
      const { data, error } = await supabase
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
        .eq('project_id', projectId);

      if (error) throw error;

      const queryResults = data as unknown as MemberQueryResult[];

      const formattedMembers: Member[] = queryResults.map(m => ({
        id: m.profiles?.id || m.user_id || m.email,
        email: m.profiles?.email || m.email,
        full_name: m.profiles?.full_name || null,
        avatar_url: m.profiles?.avatar_url || null,
        role: m.role,
        status: m.status,
        joined_at: m.joined_at,
        created_at: m.profiles?.created_at || new Date().toISOString(),
        updated_at: m.profiles?.updated_at || new Date().toISOString()
      }));

      // Sort members: active first, then by role (admin first), then by name
      const sortedMembers = formattedMembers.sort((a, b) => {
        // First sort by status (active before pending)
        if (a.status !== b.status) {
          return a.status === 'active' ? -1 : 1;
        }
        // Then by role (admin before member)
        if (a.role !== b.role) {
          return a.role === 'admin' ? -1 : 1;
        }
        // Finally by name/email
        const aName = a.full_name || a.email;
        const bName = b.full_name || b.email;
        return aName.localeCompare(bName);
      });

      setMembers(sortedMembers);
    } catch (error) {
      console.error('Error loading Giftlers:', error);
      toast.error('Failed to load Giftlers');
    } finally {
      setLoading(false);
    }
  }

  async function handleRemoveMember(memberEmail: string) {
    if (!isAdmin || !memberEmail) return;

    try {
      const { error } = await supabase
        .from('project_members')
        .delete()
        .match({ 
          project_id: projectId,
          email: memberEmail 
        });

      if (error) throw error;

      setMembers(prevMembers => 
        prevMembers.filter(member => member.email !== memberEmail)
      );
      
      toast.success('Giftler removed successfully');
      onMembersChange?.();
    } catch (error) {
      console.error('Error removing Giftler:', error);
      toast.error('Failed to remove Giftler');
    }
  }

  if (loading) {
    return (
      <div className="bg-white shadow rounded-lg p-4">
        <h3 className="text-lg font-medium text-gray-900 mb-4">Giftlers</h3>
        <LoadingScreen message="Loading Giftlers..." />
      </div>
    );
  }

  return (
    <div className="bg-white shadow rounded-lg p-4">
      <div className="flex justify-between items-center mb-4">
        <h3 className="text-lg font-medium text-gray-900">Giftlers</h3>
        {isAdmin && (
          <button
            onClick={onInviteClick}
            className="inline-flex items-center p-1 text-gray-400 hover:text-indigo-600 transition-colors"
            title="Invite Giftlers"
          >
            <PlusIcon className="h-5 w-5" />
          </button>
        )}
      </div>
      <div className="space-y-3">
        {members.map((member) => {
          const isCurrentUser = user?.id === member.id;
          const canRemove = isAdmin && !isCurrentUser && member.role !== 'admin';
          
          return (
            <div 
              key={`${member.email}-${member.joined_at}-${member.id || 'pending'}`} 
              className="flex items-center space-x-3 group"
            >
              <div className="flex-shrink-0">
                {member.avatar_url ? (
                  <img
                    src={member.avatar_url}
                    alt=""
                    className="h-8 w-8 rounded-full"
                  />
                ) : (
                  <div className={`
                    h-8 w-8 rounded-full flex items-center justify-center
                    ${member.status === 'pending' ? 'bg-yellow-100' : 'bg-gray-200'}
                  `}>
                    <span className={`
                      text-sm font-medium
                      ${member.status === 'pending' ? 'text-yellow-700' : 'text-gray-500'}
                    `}>
                      {(member.full_name || member.email || '?')[0].toUpperCase()}
                    </span>
                  </div>
                )}
              </div>
              <div className="flex-1 min-w-0">
                <div className="flex items-center space-x-2">
                  <p className="text-sm font-medium text-gray-900 truncate">
                    {member.full_name || member.email}
                  </p>
                  {isCurrentUser && (
                    <span className="text-xs text-gray-500">(You)</span>
                  )}
                  {member.status === 'pending' && (
                    <span className="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-yellow-100 text-yellow-800">
                      Pending
                    </span>
                  )}
                </div>
                <div className="flex items-center space-x-2">
                  <p className="text-xs text-gray-500 capitalize">{member.role}</p>
                </div>
              </div>
              {canRemove && (
                <button
                  onClick={() => handleRemoveMember(member.email)}
                  className="opacity-0 group-hover:opacity-100 transition-opacity p-1 text-gray-400 hover:text-red-600"
                  title="Remove Giftler"
                >
                  <TrashIcon className="h-5 w-5" />
                </button>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}