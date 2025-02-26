import { Link } from 'react-router-dom';
import CreateProjectFlow from '../components/CreateProjectFlow';
import { useAuth } from '../contexts/AuthContext';

export default function Home() {
  const { user } = useAuth();

  return (
    <div className="bg-white">
      {/* Hero Section */}
      <div className="relative isolate">
        {/* Background pattern */}
        <div className="absolute inset-x-0 -top-40 -z-10 transform-gpu overflow-hidden blur-3xl sm:-top-80"
          aria-hidden="true">
          <div className="relative left-[calc(50%-11rem)] aspect-[1155/678] w-[36.125rem] -translate-x-1/2 rotate-[30deg] bg-gradient-to-tr from-[#ff80b5] to-[#9089fc] opacity-30 sm:left-[calc(50%-30rem)] sm:w-[72.1875rem]"
            style={{
              clipPath: 'polygon(74.1% 44.1%, 100% 61.6%, 97.5% 26.9%, 85.5% 0.1%, 80.7% 2%, 72.5% 32.5%, 60.2% 62.4%, 52.4% 68.1%, 47.5% 58.3%, 45.2% 34.5%, 27.5% 76.7%, 0.1% 64.9%, 17.9% 100%, 27.6% 76.8%, 76.1% 97.7%, 74.1% 44.1%)'
            }} />
        </div>

        <div className="mx-auto max-w-2xl py-32 sm:py-48 lg:py-56">
          <div className="text-center">
            <h1 className="text-4xl font-bold tracking-tight text-gray-900 sm:text-6xl bg-clip-text text-transparent bg-gradient-to-r from-indigo-600 to-purple-600">
              Group gifting, simplified
            </h1>
            <p className="mt-6 text-lg leading-8 text-gray-600">
              Create gift projects, invite friends, and make someone's special day even more memorable.
              Organize group gifts effortlessly with our collaborative platform.
            </p>
            
            {user ? (
              <div className="mt-10">
                <Link
                  to="/dashboard"
                  className="rounded-md bg-indigo-600 px-3.5 py-2.5 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600"
                >
                  Go to Dashboard
                </Link>
              </div>
            ) : (
              <div className="mt-10">
                <CreateProjectFlow />
              </div>
            )}
          </div>
        </div>

        {/* Bottom background pattern */}
        <div className="absolute inset-x-0 top-[calc(100%-13rem)] -z-10 transform-gpu overflow-hidden blur-3xl sm:top-[calc(100%-30rem)]"
          aria-hidden="true">
          <div className="relative left-[calc(50%+3rem)] aspect-[1155/678] w-[36.125rem] -translate-x-1/2 bg-gradient-to-tr from-[#ff80b5] to-[#9089fc] opacity-30 sm:left-[calc(50%+36rem)] sm:w-[72.1875rem]"
            style={{
              clipPath: 'polygon(74.1% 44.1%, 100% 61.6%, 97.5% 26.9%, 85.5% 0.1%, 80.7% 2%, 72.5% 32.5%, 60.2% 62.4%, 52.4% 68.1%, 47.5% 58.3%, 45.2% 34.5%, 27.5% 76.7%, 0.1% 64.9%, 17.9% 100%, 27.6% 76.8%, 76.1% 97.7%, 74.1% 44.1%)'
            }} />
        </div>
      </div>

      {/* AI Feature Section */}
      <div className="overflow-hidden bg-gray-50 py-24 sm:py-32">
        <div className="mx-auto max-w-7xl px-6 lg:px-8">
          <div className="mx-auto grid max-w-2xl grid-cols-1 gap-x-8 gap-y-16 sm:gap-y-20 lg:mx-0 lg:max-w-none lg:grid-cols-2 items-center">
            <div className="lg:pr-8 lg:pt-4">
              <div className="lg:max-w-lg">
                <h2 className="text-base font-semibold leading-7 text-indigo-600">AI-Powered</h2>
                <p className="mt-2 text-3xl font-bold tracking-tight text-gray-900 sm:text-4xl">Gift Suggestions</p>
                <p className="mt-6 text-lg leading-8 text-gray-600">
                  Let our AI help you find the perfect gift based on interests and preferences. Get personalized recommendations with price comparisons.
                </p>
                <div className="mt-8">
                  <ul className="space-y-3">
                    <li className="flex gap-x-3">
                      <span className="text-indigo-600">•</span>
                      <span className="text-gray-600">AI-generated gift ideas based on interests</span>
                    </li>
                    <li className="flex gap-x-3">
                      <span className="text-indigo-600">•</span>
                      <span className="text-gray-600">Best price suggestions and comparisons</span>
                    </li>
                    <li className="flex gap-x-3">
                      <span className="text-indigo-600">•</span>
                      <span className="text-gray-600">Personalized recommendations</span>
                    </li>
                  </ul>
                </div>
              </div>
            </div>
            <div className="relative">
              <img
                src="https://images.unsplash.com/photo-1549465220-1a8b9238cd48?ixlib=rb-4.0.3&auto=format&fit=crop&w=2340&q=80"
                alt="Gift suggestions"
                className="w-full max-w-none rounded-xl shadow-xl ring-1 ring-gray-400/10"
              />
              <div className="absolute inset-0 rounded-xl bg-gradient-to-tr from-indigo-600/10 to-transparent"></div>
            </div>
          </div>
        </div>
      </div>

      {/* Yearly Reminders Section */}
      <div className="overflow-hidden py-24 sm:py-32">
        <div className="mx-auto max-w-7xl px-6 lg:px-8">
          <div className="mx-auto grid max-w-2xl grid-cols-1 gap-x-8 gap-y-16 sm:gap-y-20 lg:mx-0 lg:max-w-none lg:grid-cols-2 items-center">
            <div className="relative order-2 lg:order-1">
              <img
                src="https://images.unsplash.com/photo-1606327054629-64c8b0fd6e4f?ixlib=rb-4.0.3&auto=format&fit=crop&w=2070&q=80"
                alt="Yearly reminders"
                className="w-full max-w-none rounded-xl shadow-xl ring-1 ring-gray-400/10"
              />
              <div className="absolute inset-0 rounded-xl bg-gradient-to-bl from-indigo-600/10 to-transparent"></div>
            </div>
            <div className="lg:pl-8 lg:pt-4 order-1 lg:order-2">
              <div className="lg:max-w-lg">
                <h2 className="text-base font-semibold leading-7 text-indigo-600">Never Forget</h2>
                <p className="mt-2 text-3xl font-bold tracking-tight text-gray-900 sm:text-4xl">Yearly Reminders</p>
                <p className="mt-6 text-lg leading-8 text-gray-600">
                  Set up recurring gift projects and get reminded every year. Reuse successful gift ideas from previous years.
                </p>
                <div className="mt-8">
                  <ul className="space-y-3">
                    <li className="flex gap-x-3">
                      <span className="text-indigo-600">•</span>
                      <span className="text-gray-600">Automatic yearly project creation</span>
                    </li>
                    <li className="flex gap-x-3">
                      <span className="text-indigo-600">•</span>
                      <span className="text-gray-600">View and reuse past successful gifts</span>
                    </li>
                    <li className="flex gap-x-3">
                      <span className="text-indigo-600">•</span>
                      <span className="text-gray-600">Track gift history and preferences</span>
                    </li>
                  </ul>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Collaborative Features Section */}
      <div className="overflow-hidden bg-gray-50 py-24 sm:py-32">
        <div className="mx-auto max-w-7xl px-6 lg:px-8">
          <div className="mx-auto grid max-w-2xl grid-cols-1 gap-x-8 gap-y-16 sm:gap-y-20 lg:mx-0 lg:max-w-none lg:grid-cols-2 items-center">
            <div className="lg:pr-8 lg:pt-4">
              <div className="lg:max-w-lg">
                <h2 className="text-base font-semibold leading-7 text-indigo-600">Work Together</h2>
                <p className="mt-2 text-3xl font-bold tracking-tight text-gray-900 sm:text-4xl">Group Collaboration</p>
                <p className="mt-6 text-lg leading-8 text-gray-600">
                  Make group gifting fair and efficient with features for collaboration and task distribution.
                </p>
                <div className="mt-8">
                  <ul className="space-y-3">
                    <li className="flex gap-x-3">
                      <span className="text-indigo-600">•</span>
                      <span className="text-gray-600">Vote on gift suggestions</span>
                    </li>
                    <li className="flex gap-x-3">
                      <span className="text-indigo-600">•</span>
                      <span className="text-gray-600">Random purchaser assignment</span>
                    </li>
                    <li className="flex gap-x-3">
                      <span className="text-indigo-600">•</span>
                      <span className="text-gray-600">Fair contribution tracking</span>
                    </li>
                  </ul>
                </div>
              </div>
            </div>
            <div className="relative">
              <img
                src="https://images.unsplash.com/photo-1521737604893-d14cc237f11d?ixlib=rb-4.0.3&auto=format&fit=crop&w=2070&q=80"
                alt="Collaborative features"
                className="w-full max-w-none rounded-xl shadow-xl ring-1 ring-gray-400/10"
              />
              <div className="absolute inset-0 rounded-xl bg-gradient-to-tr from-indigo-600/10 to-transparent"></div>
            </div>
          </div>
        </div>
      </div>

      {/* CTA Section */}
      <div className="bg-gradient-to-b from-white to-indigo-50">
        <div className="px-6 py-24 sm:px-6 sm:py-32 lg:px-8">
          <div className="mx-auto max-w-2xl text-center">
            <h2 className="text-3xl font-bold tracking-tight text-gray-900 sm:text-4xl">
              Ready to start gifting together?
            </h2>
            <p className="mx-auto mt-6 max-w-xl text-lg leading-8 text-gray-600">
              Join Giftle today and experience more collaborative gift-giving with AI-powered suggestions and yearly reminders.
            </p>
            <div className="mt-10 flex items-center justify-center gap-x-6">
              <Link
                to="/register"
                className="rounded-md bg-indigo-600 px-3.5 py-2.5 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600"
              >
                Get started for free
              </Link>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}