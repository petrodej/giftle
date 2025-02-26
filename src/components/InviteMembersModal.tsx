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
  const [emailInput, setEmailInput] = useState('');
  const [emailError, setEmailError] = useState('');
  const [emails, setEmails] = useState<string[]>([]);
  const [loading, setLoading] = useState(false);

  const validateEmail = (email: string) => {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(email);
  };

  const handleAddEmail = () => {
    if (!emailInput) {
      setEmailError('Please enter an email address');
      return;
    }

    if (!validateEmail(emailInput)) {
      setEmailError('Please enter a valid email address');
      return;
    }

    if (emails.includes(emailInput)) {
      setEmailError('This email has already been added');
      return;
    }

    setEmails(prev => [...prev, emailInput]);
    setEmailInput('');
    setEmailError('');
  };

  const handleRemoveEmail = (email: string) => {
    setEmails(prev => prev.filter(e => e !== email));
  };

  const handleInvite = async (e: React.FormEvent) => {
    e.preventDefault();
    if (emails.length === 0) {
      setEmailError('Please add at least one email address');
      return;
    }

    setLoading(true);
    try {
      // Get project details for the email
      const { data: project, error: projectError } = await supabase
        .from('gift_projects')
        .select('recipient_name')
        .eq('id', projectId)
        .single();

      if (projectError) throw projectError;

      // Send emails and create member records in parallel
      const results = await Promise.all(emails.map(async (email) => {
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

          // Create notification record
          const { error: notifyError } = await supabase
            .from('pending_notifications')
            .insert({
              email,
              project_id: projectId,
              status: 'pending',
              metadata: {
                subject: 'You\'ve been invited to a Giftle project!',
                html: `
                  You've been invited to help choose a gift for ${project.recipient_name}!
                  <br><br>
                  Click here to join: <a href="${inviteUrl}">${inviteUrl}</a>
                  <br><br>
                  If you don't have a Giftle account yet, you'll be able to create one when you click the link.
                `
              }
            });

          if (notifyError) throw notifyError;

          return { email, success: true };
        } catch (error) {
          console.error('Error sending invitation to', email, ':', error);
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

      setEmails([]);
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
                <div className="space-y-2">
                  <div className="flex gap-2">
                    <div className="flex-1">
                      <input
                        type="email"
                        value={emailInput}
                        onChange={(e) => {
                          setEmailInput(e.target.value);
                          setEmailError('');
                        }}
                        onKeyPress={(e) => e.key === 'Enter' && (e.preventDefault(), handleAddEmail())}
                        placeholder="Enter email address"
                        className={`form-input w-full ${emailError ? 'border-red-300' : ''}`}
                      />
                      {emailError && (
                        <p className="mt-1 text-sm text-red-600">{emailError}</p>
                      )}
                    </div>
                    <button
                      type="button"
                      onClick={handleAddEmail}
                      disabled={!emailInput}
                      className="btn-secondary whitespace-nowrap"
                    >
                      Add
                    </button>
                  </div>

                  <div className="space-y-2">
                    {emails.map((email) => (
                      <div
                        key={email}
                        className="flex items-center justify-between bg-gray-50 px-3 py-2 rounded-lg"
                      >
                        <span className="text-sm text-gray-700">{email}</span>
                        <button
                          type="button"
                          onClick={() => handleRemoveEmail(email)}
                          className="text-gray-400 hover:text-red-600"
                        >
                          ×
                        </button>
                      </div>
                    ))}
                  </div>
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
                    disabled={loading || emails.length === 0}
                    className="btn-primary"
                  >
                    Send Invitations
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