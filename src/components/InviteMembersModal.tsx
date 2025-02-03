import React, { useState } from 'react';
import { Dialog } from '@headlessui/react';
import { supabase } from '../lib/supabase';
import toast from 'react-hot-toast';
import LoadingScreen from './LoadingScreen';

interface Props {
  projectId: string;
  inviteCode: string;
  isOpen: boolean;
  onClose: () => void;
}

export default function InviteMembersModal({ projectId, inviteCode, isOpen, onClose }: Props) {
  const [emails, setEmails] = useState('');
  const [loading, setLoading] = useState(false);

  const handleInvite = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!emails.trim()) return;

    setLoading(true);
    try {
      // Split and clean email addresses
      const emailList = emails
        .split(/[,;\n]/) // Split by comma, semicolon, or newline
        .map(email => email.toLowerCase().trim())
        .filter(email => email && email.includes('@')); // Basic validation

      if (emailList.length === 0) {
        toast.error('Please enter valid email addresses');
        return;
      }

      // Get existing users
      const { data: profiles, error: profileError } = await supabase
        .from('profiles')
        .select('id, email')
        .in('email', emailList);

      if (profileError) {
        throw new Error(`Failed to fetch profiles: ${profileError.message}`);
      }

      // Create a map of email to user id
      const emailToUserId = new Map(
        profiles?.map(profile => [profile.email, profile.id]) || []
      );

      // Prepare member entries
      const memberEntries = emailList.map(email => ({
        project_id: projectId,
        user_id: emailToUserId.get(email) || null,
        email: email,
        role: 'member',
        status: emailToUserId.get(email) ? 'active' : 'pending'
      }));

      // Insert all members
      const { error: memberError } = await supabase
        .from('project_members')
        .upsert(memberEntries, {
          onConflict: 'project_id,email',
          ignoreDuplicates: true
        });

      if (memberError) {
        throw new Error(`Failed to add members: ${memberError.message}`);
      }

      // Get the current session for authentication
      const { data: { session }, error: sessionError } = await supabase.auth.getSession();
      
      if (sessionError) {
        throw new Error(`Authentication error: ${sessionError.message}`);
      }
      
      if (!session) {
        throw new Error('No active session found');
      }

      try {
        // Call the Edge Function to process notifications immediately
        const response = await fetch(
          'https://zqedbnnolhizvogksovc.supabase.co/functions/v1/process-notifications',
          {
            method: 'POST',
            headers: {
              'Authorization': `Bearer ${session.access_token}`,
              'Content-Type': 'application/json'
            }
          }
        );

        if (!response.ok) {
          const errorText = await response.text();
          throw new Error(`HTTP error! status: ${response.status}, message: ${errorText}`);
        }

        const result = await response.json();
        if (!result.success) {
          throw new Error(result.error || 'Failed to process notifications');
        }

        toast.success(`Invitations sent to ${emailList.length} Giftler${emailList.length > 1 ? 's' : ''}`);
      } catch (notifyError) {
        console.error('Error sending invitations:', notifyError instanceof Error ? notifyError.message : 'Unknown error');
        // Still show success since members were added, but show error for notifications
        toast.success(`${emailList.length} Giftler${emailList.length > 1 ? 's' : ''} added successfully`);
        toast.error('Email notifications could not be sent');
      }

      setEmails('');
      onClose();

    } catch (error) {
      console.error('Error inviting Giftlers:', error instanceof Error ? error.message : 'Unknown error');
      toast.error(error instanceof Error ? error.message : 'Failed to send invitations');
    } finally {
      setLoading(false);
    }
  };

  const copyInviteLink = () => {
    const inviteLink = `${window.location.origin}/join/${inviteCode}`;
    navigator.clipboard.writeText(inviteLink);
    toast.success('Invite link copied to clipboard!');
  };

  return (
    <Dialog open={isOpen} onClose={onClose} className="relative z-50">
      <div className="fixed inset-0 bg-black/30" aria-hidden="true" />
      
      <div className="fixed inset-0 flex items-center justify-center p-4">
        <Dialog.Panel className="mx-auto max-w-md w-full rounded-lg bg-white p-8 shadow-xl">
          {loading ? (
            <LoadingScreen message="Sending invitations..." />
          ) : (
            <>
              <Dialog.Title className="text-xl font-semibold text-gray-900 mb-6">
                Invite Giftlers
              </Dialog.Title>

              <div className="mb-6">
                <p className="text-sm text-gray-500 mb-2">Share this invite link:</p>
                <div className="flex items-center space-x-2">
                  <code className="flex-1 bg-gray-100 p-3 rounded text-sm break-all">
                    {`${window.location.origin}/join/${inviteCode}`}
                  </code>
                  <button
                    onClick={copyInviteLink}
                    className="btn-secondary px-3 py-2 whitespace-nowrap"
                  >
                    Copy
                  </button>
                </div>
              </div>

              <div className="relative">
                <div className="absolute inset-0 flex items-center" aria-hidden="true">
                  <div className="w-full border-t border-gray-300" />
                </div>
                <div className="relative flex justify-center text-sm">
                  <span className="bg-white px-2 text-gray-500">Or invite by email</span>
                </div>
              </div>

              <form onSubmit={handleInvite} className="mt-6 space-y-6">
                <div className="form-group">
                  <label htmlFor="invite-emails" className="form-label">
                    Email addresses
                  </label>
                  <textarea
                    id="invite-emails"
                    value={emails}
                    onChange={(e) => setEmails(e.target.value)}
                    className="form-textarea"
                    rows={4}
                    placeholder="Enter email addresses&#10;Separate multiple emails with commas, semicolons, or new lines"
                  />
                  <p className="form-hint">
                    Recipients will be added as pending Giftlers until they join
                  </p>
                </div>

                <div className="flex justify-end space-x-4">
                  <button
                    type="button"
                    onClick={onClose}
                    className="btn-secondary"
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    disabled={loading || !emails.trim()}
                    className="btn-primary"
                  >
                    {loading ? 'Sending...' : 'Send Invitations'}
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