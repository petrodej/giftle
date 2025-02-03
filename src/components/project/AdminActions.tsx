import { Switch } from '@headlessui/react';

interface Props {
  isRecurring: boolean;
  hasRandomPurchaser: boolean;
  votingClosed: boolean;
  showAISuggestions: boolean;
  onToggleRecurring: (checked: boolean) => Promise<void>;
  onToggleRandomPurchaser: (checked: boolean) => Promise<void>;
  onToggleAISuggestions: (checked: boolean) => void;
  onCloseVoting: () => void;
  onReopenVoting: () => void;
  onCloseProject: () => void;
}

export default function AdminActions({
  isRecurring,
  hasRandomPurchaser,
  votingClosed,
  showAISuggestions,
  onToggleRecurring,
  onToggleRandomPurchaser,
  onToggleAISuggestions,
  onCloseVoting,
  onReopenVoting,
  onCloseProject,
}: Props) {
  const handleToggleRecurring = async (checked: boolean) => {
    try {
      await onToggleRecurring(checked);
    } catch (error) {
      // Error handling is done in the parent component
    }
  };

  const handleToggleRandomPurchaser = async (checked: boolean) => {
    try {
      await onToggleRandomPurchaser(checked);
    } catch (error) {
      // Error handling is done in the parent component
    }
  };

  return (
    <div className="border-b border-gray-200">
      <div className="p-6 space-y-6">
        <h3 className="text-lg font-medium text-gray-900">Admin Actions</h3>
        <div className="space-y-4">
          <div className="bg-gray-50 p-4 rounded-lg">
            <div className="flex items-center justify-between">
              <div>
                <h4 className="text-sm font-medium text-gray-900">Yearly Recurring</h4>
                <p className="text-sm text-gray-500">Create this project every year</p>
              </div>
              <Switch
                checked={isRecurring}
                onChange={handleToggleRecurring}
                className={`${
                  isRecurring ? 'bg-indigo-600' : 'bg-gray-200'
                } relative inline-flex h-6 w-11 flex-shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none focus:ring-2 focus:ring-indigo-600 focus:ring-offset-2`}
              >
                <span
                  className={`${
                    isRecurring ? 'translate-x-5' : 'translate-x-0'
                  } pointer-events-none relative inline-block h-5 w-5 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out`}
                />
              </Switch>
            </div>
          </div>

          <div className="bg-gray-50 p-4 rounded-lg">
            <div className="flex items-center justify-between">
              <div>
                <h4 className="text-sm font-medium text-gray-900">AI Suggestions</h4>
                <p className="text-sm text-gray-500">Get gift ideas from AI</p>
              </div>
              <Switch
                checked={showAISuggestions}
                onChange={onToggleAISuggestions}
                className={`${
                  showAISuggestions ? 'bg-indigo-600' : 'bg-gray-200'
                } relative inline-flex h-6 w-11 flex-shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none focus:ring-2 focus:ring-indigo-600 focus:ring-offset-2`}
              >
                <span
                  className={`${
                    showAISuggestions ? 'translate-x-5' : 'translate-x-0'
                  } pointer-events-none relative inline-block h-5 w-5 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out`}
                />
              </Switch>
            </div>
          </div>

          <div className="bg-gray-50 p-4 rounded-lg">
            <div className="flex items-center justify-between">
              <div>
                <h4 className="text-sm font-medium text-gray-900">Random Purchaser</h4>
                <p className="text-sm text-gray-500">Randomly assign a buyer</p>
              </div>
              <Switch
                checked={hasRandomPurchaser}
                onChange={handleToggleRandomPurchaser}
                className={`${
                  hasRandomPurchaser ? 'bg-indigo-600' : 'bg-gray-200'
                } relative inline-flex h-6 w-11 flex-shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none focus:ring-2 focus:ring-indigo-600 focus:ring-offset-2`}
              >
                <span
                  className={`${
                    hasRandomPurchaser ? 'translate-x-5' : 'translate-x-0'
                  } pointer-events-none relative inline-block h-5 w-5 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out`}
                />
              </Switch>
            </div>
          </div>
        </div>

        <div className="flex justify-end space-x-3 pt-4">
          {votingClosed ? (
            <button
              onClick={onReopenVoting}
              className="inline-flex items-center px-4 py-2 text-sm font-medium rounded-lg text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
            >
              <span className="mr-2">🎯</span>
              Open Voting
            </button>
          ) : (
            <button
              onClick={onCloseVoting}
              className="inline-flex items-center px-4 py-2 text-sm font-medium rounded-lg text-gray-700 bg-white border border-gray-300 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-gray-500"
            >
              <span className="mr-2">🔒</span>
              End Voting Phase
            </button>
          )}
          <button
            onClick={onCloseProject}
            className="inline-flex items-center px-4 py-2 text-sm font-medium rounded-lg text-white bg-gradient-to-r from-indigo-600 to-indigo-700 hover:from-indigo-700 hover:to-indigo-800 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 shadow-sm"
          >
            <span className="mr-2">✨</span>
            Complete Project
          </button>
        </div>
      </div>
    </div>
  );
}