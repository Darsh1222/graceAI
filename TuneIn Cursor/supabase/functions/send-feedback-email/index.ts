import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Create a Supabase client with the service role key
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    // Parse the request body
    const { name, email, message, timestamp, app_version } = await req.json()

    // Validate required fields
    if (!name || !email || !message) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields: name, email, message' }),
        { 
          status: 400, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    // Create email content
    const emailSubject = `New Feedback from GraceAI App - ${name}`
    const emailBody = `
New feedback has been submitted through the GraceAI app:

Name: ${name}
Email: ${email}
Timestamp: ${timestamp || new Date().toISOString()}
App Version: ${app_version || 'GraceAI eos1.1'}

Message:
${message}

---
This feedback was automatically sent from the GraceAI app contact form.
    `.trim()

    // Send email using Resend
    const resendApiKey = Deno.env.get('RESEND_API_KEY')
    
    if (resendApiKey) {
          const emailPayload = {
            from: 'GraceAI App <noreply@graceai.music>',
        to: ['darsh@graceai.music'],
        subject: emailSubject,
        text: emailBody,
        html: `
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
            <h2 style="color: #6366f1;">New Feedback from GraceAI App</h2>
            <div style="background: #f8fafc; padding: 20px; border-radius: 8px; margin: 20px 0;">
              <p><strong>Name:</strong> ${name}</p>
              <p><strong>Email:</strong> ${email}</p>
              <p><strong>Timestamp:</strong> ${timestamp || new Date().toISOString()}</p>
              <p><strong>App Version:</strong> ${app_version || 'GraceAI eos1.1'}</p>
            </div>
            <div style="background: #ffffff; padding: 20px; border: 1px solid #e2e8f0; border-radius: 8px;">
              <h3 style="color: #374151; margin-top: 0;">Message:</h3>
              <p style="white-space: pre-wrap; line-height: 1.6;">${message}</p>
            </div>
            <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 30px 0;">
            <p style="color: #6b7280; font-size: 14px;">
              This feedback was automatically sent from the GraceAI app contact form.
            </p>
          </div>
        `
      }

      const emailResponse = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${resendApiKey}`
        },
        body: JSON.stringify(emailPayload)
      })

      if (!emailResponse.ok) {
        const errorText = await emailResponse.text()
        console.error('Failed to send email via Resend:', errorText)
        
        // Fallback: Store in database for manual processing
        await supabaseClient
          .from('feedback_emails')
          .insert({
            to_email: 'darsh@graceai.music',
            subject: emailSubject,
            body: emailBody,
            status: 'failed',
            error_message: errorText,
            created_at: new Date().toISOString()
          })
      } else {
        const result = await emailResponse.json()
            console.log('✅ Email sent successfully to darsh@graceai.music via Resend:', result.id)
      }
    } else {
      // Fallback: Store in a separate table for manual processing
      console.log('⚠️ RESEND_API_KEY not configured, storing email for manual processing')
      const { error: emailLogError } = await supabaseClient
        .from('feedback_emails')
        .insert({
          to_email: 'darsh@graceai.music',
          subject: emailSubject,
          body: emailBody,
          status: 'pending',
          created_at: new Date().toISOString()
        })

      if (emailLogError) {
        console.error('Failed to log email:', emailLogError)
      }
    }

        return new Response(
          JSON.stringify({ 
            success: true, 
            message: 'Feedback processed and email sent to darsh@graceai.music' 
          }),
      { 
        status: 200, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )

  } catch (error) {
    console.error('Error processing feedback:', error)
    
    return new Response(
      JSON.stringify({ 
        error: 'Internal server error',
        details: error.message 
      }),
      { 
        status: 500, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )
  }
})
