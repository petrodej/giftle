import { useState, useRef } from 'react';
import { Link } from 'react-router-dom';
import { format, isSameMonth, isSameDay, startOfMonth, endOfMonth, eachDayOfInterval, getDay, isAfter, isBefore } from 'date-fns';
import type { GiftProject } from '../types/database';

interface Props {
  projects: GiftProject[];
}

export default function UpcomingProjects({ projects }: Props) {
  const [currentMonth, setCurrentMonth] = useState(new Date());
  const [tooltipContent, setTooltipContent] = useState<{ date: Date; x: number; y: number } | null>(null);
  const containerRef = useRef<HTMLDivElement>(null);
  
  // Get active projects sorted by date
  const activeProjects = projects
    .filter(p => {
      const projectDate = new Date(p.project_date);
      const today = new Date();

      // Include if:
      // 1. Project date is in the future
      // 2. Project is not completed
      // 3. For recurring projects, either:
      //    - It's a parent project, or
      //    - Its parent is completed
      return isAfter(projectDate, today) && 
             p.status !== 'completed' &&
             (!p.is_recurring || !p.parent_project_id || 
              projects.find(parent => parent.id === p.parent_project_id)?.status === 'completed');
    })
    .sort((a, b) => new Date(a.project_date).getTime() - new Date(b.project_date).getTime());

  const monthStart = startOfMonth(currentMonth);
  const monthEnd = endOfMonth(currentMonth);
  const daysInMonth = eachDayOfInterval({ start: monthStart, end: monthEnd });
  const startingDayIndex = getDay(monthStart);

  const getProjectsForDay = (date: Date) => {
    return activeProjects.filter(project => 
      isSameDay(new Date(project.project_date), date)
    );
  };

  const previousMonth = () => {
    setCurrentMonth(prev => new Date(prev.getFullYear(), prev.getMonth() - 1));
  };

  const nextMonth = () => {
    setCurrentMonth(prev => new Date(prev.getFullYear(), prev.getMonth() + 1));
  };

  const handleDayMouseEnter = (event: React.MouseEvent<HTMLDivElement>, date: Date) => {
    const dayProjects = getProjectsForDay(date);
    if (dayProjects.length === 0) {
      setTooltipContent(null);
      return;
    }

    const rect = event.currentTarget.getBoundingClientRect();
    const containerRect = containerRef.current?.getBoundingClientRect();
    if (!containerRect) return;

    // Calculate position relative to container
    const x = rect.left + rect.width / 2 - containerRect.left;
    const y = rect.bottom - containerRect.top;

    setTooltipContent({ date, x, y });
  };

  const handleDayMouseLeave = () => {
    setTooltipContent(null);
  };

  return (
    <div ref={containerRef} className="bg-white shadow rounded-lg relative">
      {/* Calendar Header */}
      <div className="p-4 bg-gradient-to-r from-indigo-500 to-indigo-600">
        <div className="flex items-center justify-between">
          <h2 className="text-lg font-medium text-white">Upcoming Gifts</h2>
          <div className="flex items-center space-x-4">
            <button
              onClick={previousMonth}
              className="p-1.5 text-white hover:bg-white/10 rounded-full transition-colors"
            >
              ←
            </button>
            <span className="text-sm font-medium text-white">
              {format(currentMonth, 'MMMM yyyy')}
            </span>
            <button
              onClick={nextMonth}
              className="p-1.5 text-white hover:bg-white/10 rounded-full transition-colors"
            >
              →
            </button>
          </div>
        </div>
      </div>

      {/* Calendar Grid */}
      <div className="p-4">
        {/* Weekday headers */}
        <div className="grid grid-cols-7 mb-2">
          {['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].map(day => (
            <div key={day} className="text-center">
              <span className="text-xs font-medium text-gray-500">
                {day}
              </span>
            </div>
          ))}
        </div>

        {/* Calendar days */}
        <div className="grid grid-cols-7 gap-2">
          {/* Empty cells for days before the first of the month */}
          {Array.from({ length: startingDayIndex }).map((_, index) => (
            <div key={`empty-${index}`} className="aspect-square" />
          ))}

          {daysInMonth.map(day => {
            const dayProjects = getProjectsForDay(day);
            const hasProjects = dayProjects.length > 0;
            const isToday = isSameDay(day, new Date());
            const isCurrentMonth = isSameMonth(day, currentMonth);
            const isActive = tooltipContent?.date ? isSameDay(day, tooltipContent.date) : false;
            const isPast = isBefore(day, new Date()) && !isToday;

            return (
              <div
                key={day.toString()}
                onMouseEnter={(e) => handleDayMouseEnter(e, day)}
                onMouseLeave={handleDayMouseLeave}
                className={`
                  relative aspect-square p-1 rounded-lg cursor-pointer
                  ${hasProjects ? 'hover:bg-indigo-50' : 'hover:bg-gray-50'}
                  ${hasProjects ? 'bg-indigo-50/50' : 'bg-white'}
                  ${isActive ? 'ring-2 ring-indigo-500' : hasProjects ? 'ring-1 ring-indigo-200' : ''}
                  transition-all duration-200
                  ${isPast ? 'opacity-50' : ''}
                `}
              >
                <div className={`
                  flex items-center justify-center w-7 h-7 mx-auto
                  ${isToday ? 'bg-indigo-600 text-white rounded-full' : ''}
                  ${hasProjects && !isToday ? 'font-medium text-indigo-700' : ''}
                  ${!isCurrentMonth ? 'text-gray-400' : 'text-gray-900'}
                  text-sm
                `}>
                  {format(day, 'd')}
                </div>
                
                {hasProjects && (
                  <div className="absolute bottom-1 left-1/2 -translate-x-1/2 flex justify-center space-x-0.5">
                    {dayProjects.slice(0, 3).map((project, i) => (
                      <div
                        key={i}
                        className={`
                          w-1.5 h-1.5 rounded-full
                          ${project.voting_closed ? 'bg-yellow-400' : 'bg-indigo-400'}
                        `}
                      />
                    ))}
                    {dayProjects.length > 3 && (
                      <div className="w-1.5 h-1.5 rounded-full bg-gray-300" />
                    )}
                  </div>
                )}
              </div>
            );
          })}
        </div>
      </div>

      {/* Tooltip */}
      {tooltipContent && (
        <div
          style={{
            position: 'absolute',
            left: `${tooltipContent.x}px`,
            top: `${tooltipContent.y + 8}px`, // 8px offset
            transform: 'translateX(-50%)',
          }}
          className="w-72 bg-white rounded-lg shadow-xl p-3 border border-gray-200 z-50"
        >
          <div className="font-medium text-gray-900 mb-2 border-b pb-2">
            {format(tooltipContent.date, 'MMMM d, yyyy')}
          </div>
          <div className="space-y-2">
            {getProjectsForDay(tooltipContent.date).map(project => (
              <Link
                key={project.id}
                to={`/projects/${project.id}`}
                className="block hover:bg-gray-50 rounded-lg p-2 -mx-2"
              >
                <div className="font-medium text-gray-900">
                  Gift for {project.recipient_name}
                </div>
                {project.interests && project.interests.length > 0 && (
                  <div className="mt-1 flex flex-wrap gap-1">
                    {project.interests.slice(0, 2).map((interest, i) => (
                      <span
                        key={i}
                        className="inline-flex items-center px-1.5 py-0.5 rounded-full text-xs font-medium bg-indigo-50 text-indigo-700"
                      >
                        {interest}
                      </span>
                    ))}
                    {project.interests.length > 2 && (
                      <span className="text-xs text-gray-500">
                        +{project.interests.length - 2}
                      </span>
                    )}
                  </div>
                )}
                <div className="mt-1 flex items-center">
                  <span className={`
                    inline-block w-2 h-2 rounded-full mr-2
                    ${project.voting_closed ? 'bg-yellow-400' : 'bg-indigo-400'}
                  `} />
                  <span className="text-xs text-gray-600">
                    {project.voting_closed ? 'Voting closed' : 'Voting open'}
                  </span>
                </div>
              </Link>
            ))}
          </div>
        </div>
      )}

      {/* Upcoming projects list */}
      <div className="border-t">
        <div className="p-4 space-y-2">
          <h3 className="text-sm font-medium text-gray-900 mb-3">Next up</h3>
          {activeProjects.length === 0 ? (
            <p className="text-sm text-gray-500">No upcoming gift projects</p>
          ) : (
            activeProjects.slice(0, 3).map(project => (
              <Link
                key={project.id}
                to={`/projects/${project.id}`}
                className="block p-2 hover:bg-gray-50 rounded-lg transition-colors"
              >
                <div className="flex justify-between items-start">
                  <div>
                    <div className="font-medium text-gray-900">
                      Gift for {project.recipient_name}
                    </div>
                    <div className="text-sm text-gray-500">
                      {format(new Date(project.project_date), 'MMM d, yyyy')}
                    </div>
                  </div>
                  <div className="flex items-center">
                    <span className={`
                      inline-block w-2 h-2 rounded-full mr-2
                      ${project.voting_closed ? 'bg-yellow-400' : 'bg-indigo-400'}
                    `} />
                    <span className="text-xs text-gray-600">
                      {project.voting_closed ? 'Voting closed' : 'Voting open'}
                    </span>
                  </div>
                </div>
              </Link>
            ))
          )}
        </div>
      </div>
    </div>
  );
}