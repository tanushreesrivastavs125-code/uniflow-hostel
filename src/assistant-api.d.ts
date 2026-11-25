import type { SupabaseClient } from '@supabase/supabase-js';
export function requestAssistant(db: SupabaseClient, message: string): Promise<string>;
