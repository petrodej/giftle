export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export interface Database {
  public: {
    Tables: {
      gift_projects: {
        Row: {
          id: string
          created_by: string
          recipient_name: string
          birth_date: string | null
          interests: string[]
          created_at: string
          project_date: string
          status: string
          selected_gift_id: string | null
          purchaser_id: string | null
          invite_code: string
          parent_project_id: string | null
          is_recurring: boolean
          next_occurrence_date: string | null
          min_budget: number | null
          max_budget: number | null
          budget_type: 'per_person' | 'total'
        }
        Insert: {
          id?: string
          created_by: string
          recipient_name: string
          birth_date?: string | null
          interests?: string[]
          created_at?: string
          project_date: string
          status?: string
          selected_gift_id?: string | null
          purchaser_id?: string | null
          invite_code?: string
          parent_project_id?: string | null
          is_recurring?: boolean
          next_occurrence_date?: string | null
          min_budget?: number | null
          max_budget?: number | null
          budget_type?: 'per_person' | 'total'
        }
        Update: {
          id?: string
          created_by?: string
          recipient_name?: string
          birth_date?: string | null
          interests?: string[]
          created_at?: string
          project_date?: string
          status?: string
          selected_gift_id?: string | null
          purchaser_id?: string | null
          invite_code?: string
          parent_project_id?: string | null
          is_recurring?: boolean
          next_occurrence_date?: string | null
          min_budget?: number | null
          max_budget?: number | null
          budget_type?: 'per_person' | 'total'
        }
      }
      project_members: {
        Row: {
          project_id: string
          user_id: string | null
          email: string
          joined_at: string
          role: string
          status: 'active' | 'pending'
        }
        Insert: {
          project_id: string
          user_id?: string | null
          email: string
          joined_at?: string
          role?: string
          status?: 'active' | 'pending'
        }
        Update: {
          project_id?: string
          user_id?: string | null
          email?: string
          joined_at?: string
          role?: string
          status?: 'active' | 'pending'
        }
      }
      gift_suggestions: {
        Row: {
          id: string
          project_id: string
          suggested_by: string
          title: string
          description: string | null
          price: number | null
          url: string | null
          created_at: string
          is_ai_generated: boolean
          confidence_score: number | null
          source_suggestion_id: string | null
        }
        Insert: {
          id?: string
          project_id: string
          suggested_by: string
          title: string
          description?: string | null
          price?: number | null
          url?: string | null
          created_at?: string
          is_ai_generated?: boolean
          confidence_score?: number | null
          source_suggestion_id?: string | null
        }
        Update: {
          id?: string
          project_id?: string
          suggested_by?: string
          title?: string
          description?: string | null
          price?: number | null
          url?: string | null
          created_at?: string
          is_ai_generated?: boolean
          confidence_score?: number | null
          source_suggestion_id?: string | null
        }
      }
      votes: {
        Row: {
          suggestion_id: string
          user_id: string
          created_at: string
        }
        Insert: {
          suggestion_id: string
          user_id: string
          created_at?: string
        }
        Update: {
          suggestion_id?: string
          user_id?: string
          created_at?: string
        }
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      [_ in never]: never
    }
    Enums: {
      [_ in never]: never
    }
  }
}