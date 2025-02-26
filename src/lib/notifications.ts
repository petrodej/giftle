import { supabase } from './supabase';
import toast from 'react-hot-toast';
import type { PendingNotification } from '../types/database';

export async function sendEmail(to: string, subject: string, html: string) {
  try {
    const { data: { session } } = await supabase.auth.getSession();
    if (!session) throw new Error('No active session');

    const { data: profile } = await supabase
      .from('profiles')
      .select('email')
      .eq('id', session.user.id)
      .single();

    if (!profile) throw new Error('Profile not found');

    // Create a notification record
    const { error: notifyError } = await supabase
      .from('pending_notifications')
      .insert({
        email: to,
        status: 'pending',
        metadata: {
          from: profile.email,
          subject,
          html
        }
      });

    if (notifyError) throw notifyError;

    return { success: true };
  } catch (error) {
    console.error('Error sending email:', error);
    throw error;
  }
}

export async function processNotifications() {
  try {
    const { data: { session } } = await supabase.auth.getSession();
    if (!session) throw new Error('No active session');

    // Get pending notifications with project details
    const { data: notifications, error: fetchError } = await supabase
      .from('pending_notifications')
      .select(`
        id,
        email,
        project_id,
        status,
        metadata,
        project:gift_projects!pending_notifications_project_id_fkey (
          recipient_name,
          invite_code
        )
      `)
      .eq('status', 'pending')
      .is('processed_at', null)
      .limit(10);

    if (fetchError) throw fetchError;
    if (!notifications || notifications.length === 0) return { success: true, results: [] };

    const results = [];

    // Process each notification
    for (const notification of notifications as unknown as PendingNotification[]) {
      try {
        const baseUrl = window.location.origin;
        const inviteUrl = `${baseUrl}/join/${notification.project.invite_code}`;

        // Send email using Resend
        const response = await fetch('https://api.resend.com/emails', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${import.meta.env.VITE_RESEND_API_KEY}`
          },
          body: JSON.stringify({
            from: 'onboarding@resend.dev',
            to: notification.email,
            subject: `You've been invited to a Giftle project!`,
            html: `
              You've been invited to help choose a gift for ${notification.project.recipient_name}!
              <br><br>
              Click here to join: <a href="${inviteUrl}">${inviteUrl}</a>
              <br><br>
              If you don't have a Giftle account yet, you'll be able to create one when you click the link.
            `
          })
        });

        if (!response.ok) {
          const errorData = await response.json();
          throw new Error(errorData.message || 'Failed to send email');
        }

        // Update notification status
        const { error: updateError } = await supabase
          .from('pending_notifications')
          .update({
            status: 'sent',
            processed_at: new Date().toISOString(),
          })
          .eq('id', notification.id);

        if (updateError) throw updateError;

        results.push({
          id: notification.id,
          success: true
        });

        // Show success toast for each processed notification
        toast.success(`Invitation sent to ${notification.email}`);
      } catch (error) {
        console.error('Error processing notification:', error);
        results.push({
          id: notification.id,
          success: false,
          error: error instanceof Error ? error.message : 'Unknown error'
        });

        // Update notification status to failed
        await supabase
          .from('pending_notifications')
          .update({
            status: 'failed',
            processed_at: new Date().toISOString(),
            error_message: error instanceof Error ? error.message : 'Unknown error'
          })
          .eq('id', notification.id);

        toast.error(`Failed to send invitation to ${notification.email}`);
      }
    }

    return { success: true, results };
  } catch (error) {
    console.error('Error processing notifications:', error);
    throw error;
  }
}