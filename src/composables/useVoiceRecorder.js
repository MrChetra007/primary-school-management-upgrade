import { ref } from 'vue'
import { supabase } from '@/lib/supabase'

export function useVoiceRecorder() {
  const isRecording = ref(false)
  const audioBlob = ref(null)
  const audioUrl = ref(null)
  const mediaRecorder = ref(null)
  const error = ref(null)

  function startRecording() {
    error.value = null
    audioBlob.value = null
    audioUrl.value = null

    if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
      error.value = 'ការថតសំឡេងមិនគាំទ្រនៅលើឧបករណ៍នេះទេ'
      return
    }

    navigator.mediaDevices.getUserMedia({ audio: true })
      .then(stream => {
        const recorder = new MediaRecorder(stream, { mimeType: 'audio/webm' })
        const chunks = []

        recorder.ondataavailable = (e) => {
          if (e.data.size > 0) chunks.push(e.data)
        }

        recorder.onstop = () => {
          const blob = new Blob(chunks, { type: 'audio/webm' })
          audioBlob.value = blob
          audioUrl.value = URL.createObjectURL(blob)
          stream.getTracks().forEach(track => track.stop())
        }

        recorder.onerror = () => {
          error.value = 'ការថតសំឡេងបរាជ័យ'
          stream.getTracks().forEach(track => track.stop())
        }

        recorder.start()
        mediaRecorder.value = recorder
        isRecording.value = true
      })
      .catch(() => {
        error.value = 'សូមអនុញ្ញាតិឱ្យប្រើមីក្រូហ្វូន'
      })
  }

  function stopRecording() {
    if (mediaRecorder.value && isRecording.value) {
      mediaRecorder.value.stop()
      isRecording.value = false
    }
  }

  async function uploadVoice(reportLinkId, studentId, role) {
    if (!audioBlob.value) {
      error.value = 'គ្មានសំឡេងសម្រាប់ផ្ទុកឡើង'
      return null
    }

    const fileName = `${role}.webm`
    const filePath = `${reportLinkId}/${studentId}/${fileName}`

    const { error: uploadError } = await supabase.storage
      .from('report-voices')
      .upload(filePath, audioBlob.value, {
        contentType: 'audio/webm',
        upsert: true
      })

    if (uploadError) {
      error.value = 'ការផ្ទុកសំឡេងឡើងបរាជ័យ'
      return null
    }

    const { data: { publicUrl } } = supabase.storage
      .from('report-voices')
      .getPublicUrl(filePath)

    return publicUrl
  }

  return {
    isRecording,
    audioBlob,
    audioUrl,
    error,
    startRecording,
    stopRecording,
    uploadVoice
  }
}
