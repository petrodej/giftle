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

      // Get project details for the email
      const { data: project, error: projectError } = await supabase
        .from('gift_projects')
        .select('recipient_name')
        .eq('id', projectId)
        .single();

      if (projectError) throw projectError;

      // Send emails and create member records in parallel
      const results = await Promise.all(emailList.map(async (email) => {
        try {
          // Create member record first
          const { error: memberError } = await supabase
            .from('project_members')
            .upsert({
              project_id: projectId,
              email: email,
              role: 'member',
              status: 'pending'
            }, {
              onConflict: 'project_id,email',
              ignoreDuplicates: true
            });

          if (memberError) throw memberError;

          // Construct invite URL with email parameter
          const inviteUrl = `${window.location.origin}/join/${inviteCode}?email=${encodeURIComponent(email)}`;

          // Send email via Edge Function
          const response = await fetch(`${supabase.supabaseUrl}/functions/v1/send-email`, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'Authorization': `Bearer ${supabase.supabaseKey}`
            },
            body: JSON.stringify({
              to: email,
              subject: 'You\'ve been invited to a Giftle project!',
              html: `
                You've been invited to help choose a gift for ${project.recipient_name}!
                <br><br>
                Click here to join: <a href="${inviteUrl}">${inviteUrl}</a>
                <br><br>
                If you don't have a Giftle account yet, you'll be able to create one when you click the link.
              `
            })
          });

          if (!response.ok) {
            const errorData = await response.json();
            throw new Error(errorData.error || 'Failed to send email');
          }

          const result = await response.json();

          // Log successful email send
          await supabase
            .from('pending_notifications')
            .insert({
              email,
              project_id: projectId,
              status: 'sent',
              processed_at: new Date().toISOString(),
              metadata: {
                email_id: result.data?.id,
                subject: 'You\'ve been invited to a Giftle project!'
              }
            });

          return { email, success: true };
        } catch (error) {
          console.error('Error sending invitation to', email, ':', error);
          
          // Log failed attempt
          await supabase
            .from('pending_notifications')
            .insert({
              email,
              project_id: projectId,
              status: 'failed',
              processed_at: new Date().toISOString(),
              error_message: error instanceof Error ? error.message : 'Unknown error'
            });

          return { email, success: false, error };
        }
      }));

      // Show results to user
      const successful = results.filter(r => r.success);
      const failed = results.filter(r => !r.success);

      if (successful.length > 0) {
        toast.success(`Invitations sent to ${successful.length} Giftler${successful.length > 1 ? 's' : ''}`);
      }
      if (failed.length > 0) {
        toast.error(`Failed to send ${failed.length} invitation${failed.length > 1 ? 's' : ''}`);
      }

      setEmails('');
      onClose();
    } catch (error) {
      console.error('Error inviting Giftlers:', error);
      toast.error('Failed to send invitations');
    } finally {
      setLoading(false);
    }
  };

  const copyInviteLink = () => {
    // Don't include email parameter in the copied link since it's a generic invite
    const inviteLink = `${window.location.origin}/join/${encodeURIComponent(inviteCode)}`;
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