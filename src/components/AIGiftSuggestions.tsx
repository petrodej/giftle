import { useState, useEffect } from 'react';
import { generateGiftSuggestions } from '../lib/giftAI';
import { supabase } from '../lib/supabase';
import { AIGiftSuggestion, GiftProject } from '../types/database';
import toast from 'react-hot-toast';
import LoadingScreen from './LoadingScreen';

interface Props {
  project: {
    id: string;
    interests: string[];
  };
  onSuggestionAdded: () => void;
}

export default function AIGiftSuggestions({ project, onSuggestionAdded }: Props) {
  const [suggestions, setSuggestions] = useState<AIGiftSuggestion[]>([]);
  const [loading, setLoading] = useState(false);
  const [addingIndex, setAddingIndex] = useState<number | null>(null);
  const [priceRange, setPriceRange] = useState({ min: 20, max: 200 });

  useEffect(() => {
    loadSuggestions();
  }, [project.interests, priceRange]);

  async function loadSuggestions() {
    if (!project.interests.length) return;
    
    setLoading(true);
    try {
      const aiSuggestions = await generateGiftSuggestions(
        project.interests,
        priceRange,
        'birthday' // TODO: Make this dynamic based on occasion
      );
      setSuggestions(aiSuggestions);
    } catch (error) {
      toast.error('Failed to generate gift suggestions');
    } finally {
      setLoading(false);
    }
  }

  async function addSuggestion(suggestion: AIGiftSuggestion, index: number) {
    setAddingIndex(index);
    try {
      const { error } = await supabase
        .from('gift_suggestions')
        .insert({
          project_id: project.id,
          title: suggestion.title,
          description: suggestion.description,
          price: suggestion.price,
          url: suggestion.url,
          is_ai_generated: true,
          confidence_score: suggestion.confidence_score,
        });

      if (error) throw error;
      
      toast.success('Added AI suggestion to the project');
      onSuggestionAdded();
    } catch (error) {
      toast.error('Failed to add suggestion');
    } finally {
      setAddingIndex(null);
    }
  }

  return (
    <div className="mt-8">
      <h3 className="text-lg font-medium text-gray-900">AI Gift Suggestions</h3>
      
      <div className="mt-4 space-y-4">
        <div className="flex items-center space-x-4">
          <label className="text-sm text-gray-600">
            Price Range: ${priceRange.min} - ${priceRange.max}
          </label>
          <input
            type="range"
            min="20"
            max="500"
            value={priceRange.max}
            onChange={(e) => setPriceRange(prev => ({ ...prev, max: parseInt(e.target.value) }))}
            className="w-48"
          />
          <button
            onClick={loadSuggestions}
            className="text-sm text-indigo-600 hover:text-indigo-500"
          >
            Refresh
          </button>
        </div>

        {loading ? (
          <LoadingScreen message="Generating suggestions..." />
        ) : (
          <div className="grid gap-4 md:grid-cols-2">
            {suggestions.map((suggestion, index) => (
              <div
                key={index}
                className="border rounded-lg p-4 hover:shadow-md transition-shadow"
              >
                <div className="flex justify-between items-start">
                  <div>
                    <h4 className="font-medium">{suggestion.title}</h4>
                    <p className="text-sm text-gray-600 mt-1">
                      {suggestion.description}
                    </p>
                    {suggestion.price && (
                      <p className="text-sm text-gray-600 mt-1">
                        Price: ${suggestion.price}
                      </p>
                    )}
                    <div className="mt-2 flex items-center">
                      <span className="text-xs text-gray-500">
                        Confidence: {Math.round(suggestion.confidence_score * 100)}%
                      </span>
                      <div
                        className="ml-2 h-1.5 w-16 bg-gray-200 rounded-full overflow-hidden"
                      >
                        <div
                          className="h-full bg-indigo-600"
                          style={{ width: `${suggestion.confidence_score * 100}%` }}
                        />
                      </div>
                    </div>
                  </div>
                  <button
                    onClick={() => addSuggestion(suggestion, index)}
                    disabled={addingIndex === index}
                    className={`text-indigo-600 hover:text-indigo-500 text-sm font-medium ${
                      addingIndex === index ? 'opacity-50 cursor-not-allowed' : ''
                    }`}
                  >
                    {addingIndex === index ? 'Adding...' : 'Add'}
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}