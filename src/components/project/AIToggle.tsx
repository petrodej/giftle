import { Switch } from '@headlessui/react';

interface Props {
  enabled: boolean;
  onChange: (enabled: boolean) => void;
}

export default function AIToggle({ enabled, onChange }: Props) {
  return (
    <div className="bg-gray-50 p-4 rounded-lg">
      <div className="flex items-center justify-between">
        <div>
          <h4 className="text-sm font-medium text-gray-900">AI Suggestions</h4>
          <p className="text-sm text-gray-500">Get gift ideas from AI</p>
        </div>
        <Switch
          checked={enabled}
          onChange={onChange}
          className={`${
            enabled ? 'bg-indigo-600' : 'bg-gray-200'
          } relative inline-flex h-6 w-11 flex-shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none focus:ring-2 focus:ring-indigo-600 focus:ring-offset-2`}
        >
          <span
            className={`${
              enabled ? 'translate-x-5' : 'translate-x-0'
            } pointer-events-none relative inline-block h-5 w-5 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out`}
          />
        </Switch>
      </div>
    </div>
  );
}