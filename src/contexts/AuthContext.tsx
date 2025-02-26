import React, { createContext, useContext, useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';
import type { User } from '@supabase/supabase-js';
import { useNavigate } from 'react-router-dom';

interface AuthContextType {
  user: User | null;
  loading: boolean;
  signIn: (email: string, password: string) => Promise<void>;
  signUp: (email: string, password: string) => Promise<void>;
  signOut: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);
  const navigate = useNavigate();

  useEffect(() => {
    // Check active sessions and sets the user
    supabase.auth.getSession().then(({ data: { session } }) => {
      if (session?.user) {
        setUser(session.user);
        ensureProfile(session.user);
      } else {
        handleNoSession();
      }
      setLoading(false);
    });

    const { data: { subscription } } = supabase.auth.onAuthStateChange(async (event, session) => {
      if (event === 'TOKEN_REFRESHED') {
        if (session?.user) {
          setUser(session.user);
          ensureProfile(session.user);
        }
      } else if (event === 'SIGNED_OUT') {
        handleNoSession();
      } else if (session?.user) {
        setUser(session.user);
        ensureProfile(session.user);
      } else {
        handleNoSession();
      }
    });

    return () => {
      subscription.unsubscribe();
    };
  }, [navigate]);

  const handleNoSession = () => {
    setUser(null);
    // Clear all auth data
    localStorage.removeItem('sb-zqedbnnolhizvogksovc-auth-token');
    sessionStorage.removeItem('sb-zqedbnnolhizvogksovc-auth-token');
  };

  const ensureProfile = async (user: User) => {
    try {
      const { error } = await supabase
        .from('profiles')
        .upsert(
          {
            id: user.id,
            email: user.email,
          },
          {
            onConflict: 'id',
            ignoreDuplicates: true,
          }
        );

      if (error) throw error;
    } catch (error) {
      console.error('Error ensuring profile:', error);
    }
  };

  const signIn = async (email: string, password: string) => {
    try {
      const { data, error } = await supabase.auth.signInWithPassword({ 
        email, 
        password
      });
      
      if (error) throw error;
      
      if (!data?.session) {
        throw new Error('No session returned after sign in');
      }
      
      navigate('/dashboard');
    } catch (error) {
      handleNoSession();
      throw error;
    }
  };

  const signUp = async (email: string, password: string) => {
    try {
      const { error } = await supabase.auth.signUp({ 
        email, 
        password,
        options: {
          emailRedirectTo: window.location.origin,
          data: {
            email
          }
        }
      });
      if (error) throw error;
    } catch (error) {
      handleNoSession();
      throw error;
    }
  };

  const signOut = async () => {
    try {
      handleNoSession();
      
      await supabase.auth.signOut();
      
      navigate('/');
    } catch (error) {
      console.warn('Error during sign out:', error);
      handleNoSession();
      navigate('/');
    }
  };

  return (
    <AuthContext.Provider value={{ user, loading, signIn, signUp, signOut }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}