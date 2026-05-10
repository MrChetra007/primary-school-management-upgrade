import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Create Supabase Admin client using Service Role Key
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const { action, payload } = await req.json()

    // ────────────────────────────────────────────────────────────
    // ACTION: CREATE USER (Auth + Public User + Teacher Profile)
    // ────────────────────────────────────────────────────────────
    if (action === 'create') {
      const { 
        email, password, role, school_id,
        full_name, gender, dob, phone_number, degree, address, profile_url 
      } = payload

      console.log(`Creating user: ${email} with role: ${role} for school: ${school_id}`)

      if (!school_id && role !== 'super_admin') {
        throw new Error('school_id is required for non-super_admin roles')
      }

      // 1. Create Auth User
      // Note: role and school_id in user_metadata will be picked up by the handle_new_user() trigger
      const { data: authData, error: authError } = await supabaseAdmin.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: { full_name, role, school_id }
      })

      if (authError) {
        console.error('Auth Error:', authError.message)
        throw authError
      }
      
      const userId = authData.user.id
      console.log('Auth user created:', userId)

      // 2. Create Teacher Profile (Skip for super_admin as they have no school_id)
      if (role !== 'super_admin') {
        const { error: teacherError } = await supabaseAdmin
          .from('teachers')
          .insert({
            user_id: userId,
            school_id,
            full_name,
            gender,
            dob: dob || null,
            phone_number: phone_number || null,
            degree: degree || null,
            address: address || null,
            email,
            profile_url: profile_url || null
          })

        if (teacherError) {
          console.error('Teachers Table Error:', teacherError.message)
          // Clean up: delete auth user if profile creation fails? 
          // For now, just throw and let admin handle it.
          throw teacherError
        }
        console.log('Teacher profile created')
      }

      return new Response(JSON.stringify({ success: true, userId }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      })
    }

    // ────────────────────────────────────────────────────────────
    // ACTION: RESET PASSWORD
    // ────────────────────────────────────────────────────────────
    if (action === 'reset_password') {
      const { userId, newPassword } = payload
      
      const { error } = await supabaseAdmin.auth.admin.updateUserById(userId, {
        password: newPassword
      })

      if (error) throw error

      return new Response(JSON.stringify({ success: true }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      })
    }

    // ────────────────────────────────────────────────────────────
    // ACTION: DELETE USER (Cascades to Public User + Teachers)
    // ────────────────────────────────────────────────────────────
    if (action === 'delete') {
      const { userId } = payload

      const { error } = await supabaseAdmin.auth.admin.deleteUser(userId)
      
      if (error) throw error

      return new Response(JSON.stringify({ success: true }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      })
    }

    throw new Error(`Unsupported action: ${action}`)

  } catch (error) {
    console.error('FULL EDGE FUNCTION ERROR:', error)
    return new Response(JSON.stringify({ 
      error: error.message || 'Unknown error',
      details: error
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400
    })
  }
})
