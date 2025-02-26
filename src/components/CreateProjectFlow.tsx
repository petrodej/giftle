import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { format, addDays } from 'date-fns';

interface ProjectData {
  recipientName: string;
  projectDate: string;
  emails: string[];
}

export default function CreateProjectFlow() {
  const navigate = useNavigate();
  const [step, setStep] = useState(1);
  const [projectData, setProjectData] = useState<ProjectData>({
    recipientName: '',
    projectDate: format(addDays(new Date(), 14), 'yyyy-MM-dd'),
    emails: []
  });
  const [emailInput, setEmailInput] = useState('');
  const [emailError, setEmailError] = useState('');

  const validateEmail = (email: string) => {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(email);
  };

  const handleAddEmail = () => {
    if (!emailInput) {
      setEmailError('Please enter an email address');
      return;
    }

    if (!validateEmail(emailInput)) {
      setEmailError('Please enter a valid email address');
      return;
    }

    if (projectData.emails.includes(emailInput)) {
      setEmailError('This email has already been added');
      return;
    }

    setProjectData(prev => ({
      ...prev,
      emails: [...prev.emails, emailInput]
    }));
    setEmailInput('');
    setEmailError('');
  };

  const handleRemoveEmail = (email: string) => {
    setProjectData(prev => ({
      ...prev,
      emails: prev.emails.filter(e => e !== email)
    }));
  };

  const handleContinue = () => {
    // Store project data in session storage without emails
    const { emails, ...projectDataWithoutEmails } = projectData;
    sessionStorage.setItem('pendingProject', JSON.stringify(projectDataWithoutEmails));
    navigate('/register');
  };

  return (
    <div className="max-w-md mx-auto">
      {step === 1 && (
        <div className="space-y-6">
          <div>
            <input
              type="text"
              value={projectData.recipientName}
              onChange={(e) => setProjectData(prev => ({ ...prev, recipientName: e.target.value }))}
              placeholder="Who's getting the gift? e.g., Mom's Birthday"
              className="form-input text-lg text-center w-full"
            />
          </div>

          <button
            onClick={() => setStep(2)}
            disabled={!projectData.recipientName}
            className="btn-primary w-full text-base py-3"
          >
            Start Planning 🎁
          </button>
        </div>
      )}

      {step === 2 && (
        <div className="bg-white rounded-lg shadow-lg p-6 space-y-6">
          <div>
            <h3 className="text-lg font-medium text-gray-900">When's the big day?</h3>
            <p className="mt-1 text-sm text-gray-500">
              Select the date when you need to have the gift ready
            </p>
            <input
              type="date"
              value={projectData.projectDate}
              onChange={(e) => setProjectData(prev => ({ ...prev, projectDate: e.target.value }))}
              min={format(new Date(), 'yyyy-MM-dd')}
              className="form-input mt-2"
            />
          </div>

          <div>
            <h3 className="text-lg font-medium text-gray-900">Invite Giftlers</h3>
            <p className="mt-1 text-sm text-gray-500">
              Add email addresses of people you want to invite
            </p>
            <div className="mt-2 space-y-2">
              <div className="flex gap-2">
                <div className="flex-1">
                  <input
                    type="email"
                    value={emailInput}
                    onChange={(e) => {
                      setEmailInput(e.target.value);
                      setEmailError('');
                    }}
                    onKeyPress={(e) => e.key === 'Enter' && handleAddEmail()}
                    placeholder="Enter email address"
                    className={`form-input w-full ${emailError ? 'border-red-300' : ''}`}
                  />
                  {emailError && (
                    <p className="mt-1 text-sm text-red-600">{emailError}</p>
                  )}
                </div>
                <button
                  onClick={handleAddEmail}
                  disabled={!emailInput}
                  className="btn-secondary whitespace-nowrap"
                >
                  Add
                </button>
              </div>

              <div className="space-y-2">
                {projectData.emails.map((email) => (
                  <div
                    key={email}
                    className="flex items-center justify-between bg-gray-50 px-3 py-2 rounded-lg"
                  >
                    <span className="text-sm text-gray-700">{email}</span>
                    <button
                      onClick={() => handleRemoveEmail(email)}
                      className="text-gray-400 hover:text-red-600"
                    >
                      ×
                    </button>
                  </div>
                ))}
              </div>
            </div>
          </div>

          <div className="flex gap-3">
            <button
              onClick={() => setStep(1)}
              className="btn-secondary flex-1"
            >
              Back
            </button>
            <button
              onClick={handleContinue}
              disabled={projectData.emails.length === 0}
              className="btn-primary flex-1"
            >
              Continue
            </button>
          </div>
        </div>
      )}
    </div>
  );
}