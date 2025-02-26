export interface Profile {
  id: string;
  email: string;
  full_name: string | null;
  avatar_url: string | null;
  created_at: string;
  updated_at: string;
}

export interface GiftProject {
  id: string;
  created_by: string;
  recipient_name: string;
  birth_date: string | null;
  interests: string[];
  created_at: string;
  project_date: string;
  status: 'active' | 'completed';
  selected_gift_id: string | null;
  purchaser_id: string | null;
  invite_code: string;
  parent_project_id: string | null;
  is_recurring: boolean;
  next_occurrence_date: string | null;
  min_budget: number | null;
  max_budget: number | null;
  budget_type: 'per_person' | 'total';
  voting_closed: boolean;
  completed_at: string | null;
}

export interface ProjectMember {
  project_id: string;
  user_id: string | null;
  email: string;
  joined_at: string;
  role: 'member' | 'admin';
  status: 'active' | 'pending';
}

export interface GiftSuggestion {
  id: string;
  project_id: string;
  suggested_by: string;
  title: string;
  description: string | null;
  price: number | null;
  url: string | null;
  created_at: string;
  is_ai_generated: boolean;
  confidence_score: number | null;
  source_suggestion_id: string | null;
}

export interface Vote {
  suggestion_id: string;
  user_id: string;
  created_at: string;
  medal: 'gold' | 'silver' | 'bronze' | null;
}

export interface AIGiftSuggestion {
  title: string;
  description: string;
  price: number | null;
  url: string | null;
  confidence_score: number;
}

export interface MemberQueryResult {
  user_id: string | null;
  role: string;
  status: 'active' | 'pending';
  email: string;
  joined_at: string;
  profiles: {
    id: string;
    email: string;
    full_name: string | null;
    avatar_url: string | null;
    created_at: string;
    updated_at: string;
  } | null;
}

export interface PendingNotification {
  id: string;
  email: string;
  project_id: string;
  status: string;
  metadata: {
    from?: string;
    subject: string;
    html: string;
  };
  project: {
    recipient_name: string;
    invite_code: string;
  };
}