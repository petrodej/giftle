import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';
import { Resend } from 'npm:resend';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Initialize Supabase client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    // Initialize Resend
    const resend = new Resend(Deno.env.get('RESEND_API_KEY'));

    // Get pending notifications with explicit join
    const { data: notifications, error: fetchError } = await supabaseClient
      .from('pending_notifications')
      .select(`
        id,
        email,
        project_id,
        project:project_id (
          recipient_name,
          invite_code
        )
      `)
      .eq('status', 'pending')
      .is('processed_at', null)
      .limit(10);

    if (fetchError) throw fetchError;

    const results = [];

    // Process each notification
    for (const notification of notifications) {
      try {
        const baseUrl = 'https://giftle.stackblitz.io'; // TODO: Make configurable
        const inviteUrl = `${baseUrl}/join/${notification.project.invite_code}`;

        // Send email
        const { data: emailData, error: emailError } = await resend.emails.send({
          from: 'onboarding@resend.dev',
          to: notification.email,
          subject: 'You\'ve been invited to a Giftle project!',
          html: `
            You've been invited to help choose a gift for ${notification.project.recipient_name}!
            <br><br>
            Click here to join: <a href="${inviteUrl}">${inviteUrl}</a>
            <br><br>
            If you don't have a Giftle account yet, you'll be able to create one when you click the link.
          `,
        });

        if (emailError) throw emailError;

        // Update notification status
        const { error: updateError } = await supabaseClient
          .from('pending_notifications')
          .update({
            status: 'sent',
            processed_at: new Date().toISOString(),
          })
          .eq('id', notification.id);

        if (updateError) throw updateError;

        results.push({
          id: notification.id,
          success: true,
          emailId: emailData.id,
        });
      } catch (error) {
        results.push({
          id: notification.id,
          success: false,
          error: error.message,
        });

        // Update notification status to failed
        await supabaseClient
          .from('pending_notifications')
          .update({
            status: 'failed',
            processed_at: new Date().toISOString(),
          })
          .eq('id', notification.id);
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        results,
      }),
      {
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
        status: 200,
      },
    );
  } catch (error) {
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message,
      }),
      {
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
        status: 400,
      },
    );
  }
});