import { Link } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import { useState } from 'react';
import { Menu } from '@headlessui/react';

export default function Navbar() {
  const { user, signOut } = useAuth();
  const [avatarError, setAvatarError] = useState(false);

  const handleSignOut = async () => {
    try {
      await signOut();
    } catch (error) {
      console.error('Error signing out:', error);
    }
  };

  const getInitial = () => {
    if (!user?.email) return '?';
    return user.email[0].toUpperCase();
  };

  const getDisplayName = () => {
    return user?.user_metadata?.full_name || user?.email || 'User';
  };

  return (
    <nav className="bg-white shadow-sm relative z-50">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <div className="flex h-16 justify-between items-center">
          <div className="flex">
            <Link 
              to="/" 
              className="flex flex-shrink-0 items-center"
            >
              <span className="text-2xl font-bold text-indigo-600">Giftle</span>
            </Link>
          </div>
          <div className="flex items-center space-x-4">
            {user ? (
              <>
                <Link
                  to="/dashboard"
                  className="text-gray-700 hover:text-gray-900 px-3 py-2 text-sm font-medium"
                >
                  Dashboard
                </Link>
                <Menu as="div" className="relative">
                  <div className="group relative">
                    <Menu.Button className="flex items-center">
                      <span className="sr-only">Open user menu</span>
                      {user.user_metadata?.avatar_url && !avatarError ? (
                        <img
                          src={user.user_metadata.avatar_url}
                          alt=""
                          className="h-8 w-8 rounded-full object-cover"
                          onError={() => setAvatarError(true)}
                        />
                      ) : (
                        <div className="h-8 w-8 rounded-full bg-indigo-600 flex items-center justify-center">
                          <span className="text-sm font-medium text-white">
                            {getInitial()}
                          </span>
                        </div>
                      )}
                    </Menu.Button>
                    {/* Tooltip */}
                    <div className="absolute right-0 top-full mt-1 invisible opacity-0 group-hover:visible group-hover:opacity-100 transition-all duration-200">
                      <div className="bg-gray-900 text-white text-sm rounded-lg py-1 px-3 whitespace-nowrap">
                        {getDisplayName()}
                      </div>
                      <div className="absolute -top-1 right-3 w-2 h-2 bg-gray-900 transform rotate-45" />
                    </div>
                  </div>
                  <Menu.Items className="absolute right-0 mt-2 w-48 origin-top-right rounded-lg bg-white py-1 shadow-lg ring-1 ring-black ring-opacity-5 focus:outline-none">
                    <Menu.Item>
                      {({ active }) => (
                        <button
                          onClick={handleSignOut}
                          className={`${
                            active ? 'bg-gray-50' : ''
                          } block w-full px-4 py-2 text-left text-sm text-gray-700`}
                        >
                          Sign out
                        </button>
                      )}
                    </Menu.Item>
                  </Menu.Items>
                </Menu>
              </>
            ) : (
              <>
                <Link
                  to="/login"
                  className="text-gray-700 hover:text-gray-900 px-3 py-2 text-sm font-medium"
                >
                  Sign in
                </Link>
                <Link
                  to="/register"
                  className="ml-4 bg-indigo-600 text-white hover:bg-indigo-500 px-3 py-2 rounded-md text-sm font-medium"
                >
                  Sign up
                </Link>
              </>
            )}
          </div>
        </div>
      </div>
    </nav>
  );
}