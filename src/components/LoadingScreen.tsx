import { type FC } from 'react';

interface Props {
  fullScreen?: boolean;
  message?: string;
}

const LoadingScreen: FC<Props> = ({ fullScreen = false, message = 'Loading...' }) => {
  const content = (
    <div className="flex flex-col items-center justify-center space-y-4">
      <div className="relative">
        <div className="h-12 w-12">
          <div className="absolute h-12 w-12 rounded-full border-4 border-gray-200"></div>
          <div className="absolute h-12 w-12 rounded-full border-4 border-indigo-600 border-t-transparent animate-spin"></div>
        </div>
      </div>
      <p className="text-sm text-gray-500 animate-pulse">{message}</p>
    </div>
  );

  if (fullScreen) {
    return (
      <div className="fixed inset-0 bg-white bg-opacity-90 z-50 flex items-center justify-center">
        {content}
      </div>
    );
  }

  return (
    <div className="flex items-center justify-center py-12">
      {content}
    </div>
  );
};

export default LoadingScreen;