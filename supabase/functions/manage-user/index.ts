import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const { action, payload } = await req.json()

    // ────────────────────────────────────────────────────────────
    // ACTION: CREATE USER
    // ────────────────────────────────────────────────────────────
    if (action === 'create') {
      const {
        email, password, role, school_id,
        full_name, gender, dob, phone_number, degree, address, profile_url
      } = payload

      console.log('Creating user:', email, '| role:', role, '| school_id:', school_id)

      if (!school_id && role !== 'super_admin') {
        throw new Error('school_id is required for non-super_admin roles')
      }

      // Step 1: Create auth user
      // handle_new_user() trigger fires here → inserts public.users row
      const { data: authData, error: authError } = await supabaseAdmin.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: {
          role,
          school_id: school_id ?? ''   // always a string — trigger casts to uuid safely
        }
      })

      if (authError) {
        console.error('Auth create error:', authError.message)
        throw authError
      }

      const userId = authData.user.id
      console.log('Auth user created:', userId)

      // Step 2: Verify public.users row exists (created by trigger)
      // If the trigger failed silently, this catches it before teachers insert
      const { data: userRow, error: userCheckError } = await supabaseAdmin
        .from('users')
        .select('id')
        .eq('id', userId)
        .single()

      if (userCheckError || !userRow) {
        console.error('public.users row missing after trigger — inserting manually')
        // Trigger failed — insert manually as fallback
        const { error: manualUserError } = await supabaseAdmin
          .from('users')
          .insert({
            id: userId,
            email,
            role,
            school_id: school_id || null
          })

        if (manualUserError) {
          console.error('Manual users insert failed:', manualUserError.message)
          await supabaseAdmin.auth.admin.deleteUser(userId)
          throw new Error('Failed to create user profile: ' + manualUserError.message)
        }
        console.log('public.users row created manually as fallback')
      }

      // Step 3: Create teacher profile (all roles except super_admin)
      if (role !== 'super_admin') {
        const { error: teacherError } = await supabaseAdmin
          .from('teachers')
          .insert({
            user_id: userId,
            school_id,
            full_name,
            gender:       gender       || null,
            dob:          dob          || null,
            phone_number: phone_number || null,
            degree:       degree       || null,
            address:      address      || null,
            email,
            profile_url:  profile_url  || null
          })

        if (teacherError) {
          console.error('Teachers insert error:', teacherError.message)
          // Clean up to avoid orphaned auth user
          await supabaseAdmin.auth.admin.deleteUser(userId)
          throw new Error('Failed to create teacher profile: ' + teacherError.message)
        }
        console.log('Teacher profile created for:', userId)
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
    // ACTION: DELETE USER
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
    console.error('Edge function error:', error)
    return new Response(JSON.stringify({
      error: error.message || 'Unknown error'
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400
    })
  }
})